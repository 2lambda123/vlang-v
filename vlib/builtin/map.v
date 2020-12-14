// Copyright (c) 2019-2020 Alexander Medvednikov. All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.
module builtin

// import hash.wyhash as hash
import hash

/*
This is a highly optimized hashmap implementation. It has several traits that
in combination makes it very fast and memory efficient. Here is a short expl-
anation of each trait. After reading this you should have a basic understand-
ing of how it functions:

1. Hash-function: Wyhash. Wyhash is the fastest hash-function for short keys
passing SMHasher, so it was an obvious choice.

2. Open addressing: Robin Hood Hashing. With this method, a hash-collision is
resolved by probing. As opposed to linear probing, Robin Hood hashing has a
simple but clever twist: As new keys are inserted, old keys are shifted arou-
nd in a way such that all keys stay reasonably close to the slot they origin-
ally hash to. A new key may displace a key already inserted if its probe cou-
nt is larger than that of the key at the current position.

3. Memory layout: key-value pairs are stored in a `DenseArray`. This is a dy-
namic array with a very low volume of unused memory, at the cost of more rea-
llocations when inserting elements. It also preserves the order of the key-v-
alues. This array is named `key_values`. Instead of probing a new key-value,
this map probes two 32-bit numbers collectively. The first number has its 8
most significant bits reserved for the probe-count and the remaining 24 bits
are cached bits from the hash which are utilized for faster re-hashing. This
number is often referred to as `meta`. The other 32-bit number is the index
at which the key-value was pushed to in `key_values`. Both of these numbers
are stored in a sparse array `metas`. The `meta`s and `kv_index`s are stored
at even and odd indices, respectively:

metas = [meta, kv_index, 0, 0, meta, kv_index, 0, 0, meta, kv_index, ...]
key_values = [kv, kv, kv, ...]

4. The size of metas is a power of two. This enables the use of bitwise AND
to convert the 64-bit hash to a bucket/index that doesn't overflow metas. If
the size is power of two you can use "hash & (SIZE - 1)" instead of "hash %
SIZE". Modulo is extremely expensive so using '&' is a big performance impro-
vement. The general concern with this approach is that you only make use of
the lower bits of the hash which can cause more collisions. This is solved by
using a well-dispersed hash-function.

5. The hashmap keeps track of the highest probe_count. The trick is to alloc-
ate `extra_metas` > max(probe_count), so you never have to do any bounds-che-
cking since the extra meta memory ensures that a meta will never go beyond
the last index.

6. Cached rehashing. When the `load_factor` of the map exceeds the `max_load_
factor` the size of metas is doubled and all the key-values are "rehashed" to
find the index for their meta's in the new array. Instead of rehashing compl-
etely, it simply uses the cached-hashbits stored in the meta, resulting in
much faster rehashing.
*/
const (
	// Number of bits from the hash stored for each entry
	hashbits            = 24
	// Number of bits from the hash stored for rehashing
	max_cached_hashbits = 16
	// Initial log-number of buckets in the hashtable
	init_log_capicity   = 5
	// Initial number of buckets in the hashtable
	init_capicity       = 1 << init_log_capicity
	// Maximum load-factor (len / capacity)
	max_load_factor     = 0.8
	// Initial highest even index in metas
	init_cap            = init_capicity - 2
	// Used for incrementing `extra_metas` when max
	// probe count is too high, to avoid overflow
	extra_metas_inc     = 4
	// Bitmask to select all the hashbits
	hash_mask           = u32(0x00FFFFFF)
	// Used for incrementing the probe-count
	probe_inc           = u32(0x01000000)
)

// This function is intended to be fast when
// the strings are very likely to be equal
// TODO: add branch prediction hints
[inline]
fn fast_string_eq(a string, b string) bool {
	if a.len != b.len {
		return false
	}
	unsafe {
		return C.memcmp(a.str, b.str, b.len) == 0
	}
}

// Dynamic array with very low growth factor
struct DenseArray {
	key_bytes   int
	value_bytes int
	slot_bytes  int // sum of 2 fields above
mut:
	cap         int
	len         int
	deletes     u32 // count
	// array allocated (with `cap` bytes) on first deletion
	// has non-zero element when key deleted
	all_deleted &byte
	data        byteptr // array of interleaved key data and value data
}

[inline]
[unsafe]
fn new_dense_array(key_bytes int, value_bytes int) DenseArray {
	slot_bytes := key_bytes + value_bytes
	cap := 8
	return DenseArray{
		key_bytes: key_bytes
		value_bytes: value_bytes
		slot_bytes: slot_bytes
		cap: cap
		len: 0
		deletes: 0
		all_deleted: 0
		data: malloc(cap * slot_bytes)
	}
}

[inline]
fn (d &DenseArray) key(i int) voidptr {
	return unsafe {d.data + i * d.slot_bytes}
}

// for cgen
[inline]
fn (d &DenseArray) value(i int) voidptr {
	return unsafe {d.data + i * d.slot_bytes + d.key_bytes}
}

[inline]
fn (d &DenseArray) has_index(i int) bool {
	return d.deletes == 0 || unsafe {d.all_deleted[i]} == 0
}

// Push element to array and return index
// The growth-factor is roughly 1.125 `(x + (x >> 3))`
[inline]
fn (mut d DenseArray) push(key voidptr, value voidptr) int {
	if d.cap == d.len {
		d.cap += d.cap >> 3
		unsafe {
			d.data = v_realloc(d.data, d.slot_bytes * d.cap)
			if d.deletes != 0 {
				d.all_deleted = v_realloc(d.all_deleted, d.cap)
				C.memset(d.all_deleted + d.len, 0, d.cap - d.len)
			}
		}
	}
	push_index := d.len
	unsafe {
		if d.deletes != 0 {
			d.all_deleted[push_index] = 0
		}
		ptr := d.key(push_index)
		C.memcpy(ptr, key, d.key_bytes)
		C.memcpy(byteptr(ptr) + d.key_bytes, value, d.value_bytes)
	}
	d.len++
	return push_index
}

// Move all zeros to the end of the array and resize array
fn (mut d DenseArray) zeros_to_end() {
	// TODO alloca?
	mut tmp_buf := malloc(d.slot_bytes)
	mut count := 0
	for i in 0 .. d.len {
		if d.has_index(i) {
			// swap (TODO: optimize)
			unsafe {
				C.memcpy(tmp_buf, d.key(count), d.slot_bytes)
				C.memcpy(d.key(count), d.key(i), d.slot_bytes)
				C.memcpy(d.key(i), tmp_buf, d.slot_bytes)
			}
			count++
		}
	}
	free(tmp_buf)
	d.deletes = 0
	// TODO: reallocate instead as more deletes are likely
	free(d.all_deleted)
	d.len = count
	d.cap = if count < 8 { 8 } else { count }
	unsafe {
		d.data = v_realloc(d.data, d.slot_bytes * d.cap)
	}
}

pub struct map {
	// Number of bytes of a key
	key_bytes       int
	// Number of bytes of a value
	value_bytes     int
mut:
	// Highest even index in the hashtable
	cap             u32
	// Number of cached hashbits left for rehasing
	cached_hashbits byte
	// Used for right-shifting out used hashbits
	shift           byte
	// Array storing key-values (ordered)
	key_values      DenseArray
	// Pointer to meta-data:
	// - Odd indices store kv_index.
	// - Even indices store probe_count and hashbits.
	metas           &u32
	// Extra metas that allows for no ranging when incrementing
	// index in the hashmap
	extra_metas     u32
pub mut:
	// Number of key-values currently in the hashmap
	len             int
}

fn new_map_1(value_bytes int) map {
	metasize := int(sizeof(u32) * (init_capicity + extra_metas_inc))
	key_bytes := int(sizeof(string))
	return map{
		key_bytes: key_bytes
		value_bytes: value_bytes
		cap: init_cap
		cached_hashbits: max_cached_hashbits
		shift: init_log_capicity
		key_values: new_dense_array(key_bytes, value_bytes)
		metas: &u32(vcalloc(metasize))
		extra_metas: extra_metas_inc
		len: 0
	}
}

fn new_map_init(n int, value_bytes int, keys &string, values voidptr) map {
	mut out := new_map_1(value_bytes)
	for i in 0 .. n {
		unsafe {out.set(keys[i], byteptr(values) + i * value_bytes)}
	}
	return out
}

[inline]
fn (m &map) keys_eq(a voidptr, b voidptr) bool {
	// assume string for now
	return fast_string_eq(*&string(a), *&string(b))
}

[inline]
fn (m &map) key_to_index(pkey voidptr) (u32, u32) {
	key := *&string(pkey)
	hash := hash.wyhash_c(key.str, u64(key.len), 0)
	index := hash & m.cap
	meta := ((hash >> m.shift) & hash_mask) | probe_inc
	return u32(index), u32(meta)
}

[inline]
fn (m &map) meta_less(_index u32, _metas u32) (u32, u32) {
	mut index := _index
	mut meta := _metas
	for meta < unsafe {m.metas[index]} {
		index += 2
		meta += probe_inc
	}
	return index, meta
}

[inline]
fn (mut m map) meta_greater(_index u32, _metas u32, kvi u32) {
	mut meta := _metas
	mut index := _index
	mut kv_index := kvi
	for unsafe {m.metas[index]} != 0 {
		if meta > unsafe {m.metas[index]} {
			unsafe {
				tmp_meta := m.metas[index]
				m.metas[index] = meta
				meta = tmp_meta
				tmp_index := m.metas[index + 1]
				m.metas[index + 1] = kv_index
				kv_index = tmp_index
			}
		}
		index += 2
		meta += probe_inc
	}
	unsafe {
		m.metas[index] = meta
		m.metas[index + 1] = kv_index
	}
	probe_count := (meta >> hashbits) - 1
	m.ensure_extra_metas(probe_count)
}

[inline]
fn (mut m map) ensure_extra_metas(probe_count u32) {
	if (probe_count << 1) == m.extra_metas {
		m.extra_metas += extra_metas_inc
		mem_size := (m.cap + 2 + m.extra_metas)
		unsafe {
			x := v_realloc(byteptr(m.metas), int(sizeof(u32) * mem_size))
			m.metas = &u32(x)
			C.memset(m.metas + mem_size - extra_metas_inc, 0, int(sizeof(u32) * extra_metas_inc))
		}
		// Should almost never happen
		if probe_count == 252 {
			panic('Probe overflow')
		}
	}
}

// Insert new element to the map. The element is inserted if its key is
// not equivalent to the key of any other element already in the container.
// If the key already exists, its value is changed to the value of the new element.
fn (mut m map) set(k string, value voidptr) {
	key := k.clone()
	load_factor := f32(m.len << 1) / f32(m.cap)
	if load_factor > max_load_factor {
		m.expand()
	}
	mut index, mut meta := m.key_to_index(&key)
	index, meta = m.meta_less(index, meta)
	// While we might have a match
	for meta == unsafe {m.metas[index]} {
		kv_index := int(unsafe {m.metas[index + 1]})
		pkey := unsafe {m.key_values.key(kv_index)}
		if m.keys_eq(&key, pkey) {
			unsafe {
				pval := byteptr(pkey) + m.key_bytes
				C.memcpy(pval, value, m.value_bytes)
			}
			return
		}
		index += 2
		meta += probe_inc
	}
	kv_index := m.key_values.push(key, value)
	m.meta_greater(index, meta, u32(kv_index))
	m.len++
}

// Doubles the size of the hashmap
fn (mut m map) expand() {
	old_cap := m.cap
	m.cap = ((m.cap + 2) << 1) - 2
	// Check if any hashbits are left
	if m.cached_hashbits == 0 {
		m.shift += max_cached_hashbits
		m.cached_hashbits = max_cached_hashbits
		m.rehash()
	} else {
		m.cached_rehash(old_cap)
		m.cached_hashbits--
	}
}

// A rehash is the reconstruction of the hash table:
// All the elements in the container are rearranged according
// to their hash value into the newly sized key-value container.
// Rehashes are performed when the load_factor is going to surpass
// the max_load_factor in an operation.
fn (mut m map) rehash() {
	meta_bytes := sizeof(u32) * (m.cap + 2 + m.extra_metas)
	unsafe {
		x := v_realloc(byteptr(m.metas), int(meta_bytes))
		m.metas = &u32(x)
		C.memset(m.metas, 0, meta_bytes)
	}
	for i := 0; i < m.key_values.len; i++ {
		if !m.key_values.has_index(i) {
			continue
		}
		pkey := unsafe {m.key_values.key(i)}
		mut index, mut meta := m.key_to_index(pkey)
		index, meta = m.meta_less(index, meta)
		m.meta_greater(index, meta, u32(i))
	}
}

// This method works like rehash. However, instead of rehashing the
// key completely, it uses the bits cached in `metas`.
fn (mut m map) cached_rehash(old_cap u32) {
	old_metas := m.metas
	metasize := int(sizeof(u32) * (m.cap + 2 + m.extra_metas))
	m.metas = &u32(vcalloc(metasize))
	old_extra_metas := m.extra_metas
	for i := u32(0); i <= old_cap + old_extra_metas; i += 2 {
		if unsafe {old_metas[i]} == 0 {
			continue
		}
		old_meta := unsafe {old_metas[i]}
		old_probe_count := ((old_meta >> hashbits) - 1) << 1
		old_index := (i - old_probe_count) & (m.cap >> 1)
		mut index := (old_index | (old_meta << m.shift)) & m.cap
		mut meta := (old_meta & hash_mask) | probe_inc
		index, meta = m.meta_less(index, meta)
		kv_index := unsafe {old_metas[i + 1]}
		m.meta_greater(index, meta, kv_index)
	}
	unsafe {free(old_metas)}
}

// This method is used for assignment operators. If the argument-key
// does not exist in the map, it's added to the map along with the zero/default value.
// If the key exists, its respective value is returned.
fn (mut m map) get_and_set(key string, zero voidptr) voidptr {
	for {
		mut index, mut meta := m.key_to_index(&key)
		for {
			if meta == unsafe {m.metas[index]} {
				kv_index := int(unsafe {m.metas[index + 1]})
				pkey := unsafe {m.key_values.key(kv_index)}
				if m.keys_eq(&key, pkey) {
					return unsafe {byteptr(pkey) + m.key_values.key_bytes}
				}
			}
			index += 2
			meta += probe_inc
			if meta > unsafe {m.metas[index]} {
				break
			}
		}
		// Key not found, insert key with zero-value
		m.set(key, zero)
	}
	assert false
	return voidptr(0)
}

// If `key` matches the key of an element in the container,
// the method returns a reference to its mapped value.
// If not, a zero/default value is returned.
fn (m map) get(key string, zero voidptr) voidptr {
	mut index, mut meta := m.key_to_index(&key)
	for {
		if meta == unsafe {m.metas[index]} {
			kv_index := int(unsafe {m.metas[index + 1]})
			pkey := unsafe {m.key_values.key(kv_index)}
			if m.keys_eq(&key, pkey) {
				return unsafe {byteptr(pkey) + m.key_values.key_bytes}
			}
		}
		index += 2
		meta += probe_inc
		if meta > unsafe {m.metas[index]} {
			break
		}
	}
	return zero
}

// Checks whether a particular key exists in the map.
fn (m map) exists(key string) bool {
	mut index, mut meta := m.key_to_index(&key)
	for {
		if meta == unsafe {m.metas[index]} {
			kv_index := int(unsafe {m.metas[index + 1]})
			pkey := unsafe {m.key_values.key(kv_index)}
			if m.keys_eq(&key, pkey) {
				return true
			}
		}
		index += 2
		meta += probe_inc
		if meta > unsafe {m.metas[index]} {
			break
		}
	}
	return false
}

// Removes the mapping of a particular key from the map.
pub fn (mut m map) delete(key string) {
	mut index, mut meta := m.key_to_index(&key)
	index, meta = m.meta_less(index, meta)
	// Perform backwards shifting
	for meta == unsafe {m.metas[index]} {
		kv_index := int(unsafe {m.metas[index + 1]})
		pkey := unsafe {&string(m.key_values.key(kv_index))}
		if m.keys_eq(&key, pkey) {
			for (unsafe {m.metas[index + 2]} >> hashbits) > 1 {
				unsafe {
					m.metas[index] = m.metas[index + 2] - probe_inc
					m.metas[index + 1] = m.metas[index + 3]
				}
				index += 2
			}
			m.len--
			if m.key_values.deletes == 0 {
				m.key_values.all_deleted = C.calloc(1, m.cap) // sets to 0
			}
			m.key_values.deletes++
			unsafe {
				m.key_values.all_deleted[kv_index] = 1
				m.metas[index] = 0
				// Mark key as deleted
				(*pkey).free()
				C.memset(pkey, 0, sizeof(string))
			}
			if m.key_values.len <= 32 {
				return
			}
			// Clean up key_values if too many have been deleted
			if m.key_values.deletes >= (m.key_values.len >> 1) {
				m.key_values.zeros_to_end()
				m.rehash()
			}
			return
		}
		index += 2
		meta += probe_inc
	}
}

// Returns all keys in the map.
pub fn (m &map) keys() []string {
	mut keys := []string{len: m.len}
	mut j := 0
	if m.key_values.deletes == 0 {
		for i := 0; i < m.key_values.len; i++ {
			pkey := unsafe {&string(m.key_values.key(i))}
			keys[j] = pkey.clone()
			j++
		}
		return keys
	}
	for i := 0; i < m.key_values.len; i++ {
		if !m.key_values.has_index(i) {
			continue
		}
		pkey := unsafe {&string(m.key_values.key(i))}
		keys[j] = pkey.clone()
		j++
	}
	return keys
}

[unsafe]
pub fn (d DenseArray) clone() DenseArray {
	res := DenseArray{
		key_bytes: d.key_bytes
		value_bytes: d.value_bytes
		slot_bytes: d.slot_bytes
		cap: d.cap
		len: d.len
		deletes: d.deletes
		all_deleted: 0
		data: 0
	}
	unsafe {
		if d.deletes != 0 {
			res.all_deleted = memdup(d.all_deleted, d.cap)
		}
		res.data = memdup(d.data, d.cap * d.slot_bytes)
	}
	// FIXME clone each key
	return res
}

[unsafe]
pub fn (m map) clone() map {
	metasize := int(sizeof(u32) * (m.cap + 2 + m.extra_metas))
	res := map{
		key_bytes: m.key_bytes
		value_bytes: m.value_bytes
		cap: m.cap
		cached_hashbits: m.cached_hashbits
		shift: m.shift
		key_values: unsafe {m.key_values.clone()}
		metas: &u32(malloc(metasize))
		extra_metas: m.extra_metas
		len: m.len
	}
	unsafe {C.memcpy(res.metas, m.metas, metasize)}
	return res
}

[unsafe]
pub fn (m &map) free() {
	unsafe {free(m.metas)}
	if m.key_values.deletes == 0 {
		for i := 0; i < m.key_values.len; i++ {
			unsafe {
				pkey := &string(m.key_values.key(i))
				(*pkey).free()
			}
		}
	} else {
		for i := 0; i < m.key_values.len; i++ {
			if !m.key_values.has_index(i) {
				continue
			}
			unsafe {
				pkey := &string(m.key_values.key(i))
				(*pkey).free()
			}
		}
		unsafe {free(m.key_values.all_deleted)}
	}
	unsafe {free(m.key_values.data)}
}
