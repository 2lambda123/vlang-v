module table

import v.types

[inline]
pub fn (t &Table) find_type_idx(name string) int {
	return t.type_idxs[name]
}

[inline]
pub fn (t &Table) find_type(name string) ?types.Type {
	idx := t.type_idxs[name]
	if idx > 0 {
		return t.types[idx]
	}
	return none
}

pub fn (t mut Table) register_struct(typ types.Struct) int {
	mut t2 := types.Type{}
	// existing
	existing_idx := t.type_idxs[typ.name]
	if existing_idx > 0 {
		ex_type := t.types[existing_idx]
		match ex_type {
			types.Placeholder {
				// override placeholder
				println('overriding type placeholder `$it.name` with struct')
				t2 = {typ| idx: existing_idx}
				t.types[existing_idx] = t2
				return existing_idx
			}
			types.Struct {
				return existing_idx
			}
			else {
				panic('cannot register type `$typ.name`, another type with this name exists')
			}
		}
	}
	// register
	println('registering: $typ.name')
	idx := t.types.len
	t.type_idxs[typ.name] = idx
	t2 = {typ| idx: idx}
	t.types << t2

	return idx
}

pub fn (t mut Table) find_or_register_map(key_ti &types.TypeIdent, value_ti &types.TypeIdent) (int, string) {
	name := 'map_${key_ti.type_name}_${value_ti.type_name}'
	// existing
	existing_idx := t.type_idxs[name]
	if existing_idx > 0 {
		return existing_idx, name
	}
	// register
	idx := t.types.len
	mut map_type := types.Type{}
	map_type = types.Map{
		name: name
		key_type_idx: key_ti.type_idx,
		value_type_idx: value_ti.type_idx
	}
	t.type_idxs[name] = idx
	t.types << map_type
	return idx, name
}

pub fn (t mut Table) find_or_register_array(elem_ti &types.TypeIdent, nr_dims int) (int, string) {
	name := 'array_${elem_ti.type_name}_${nr_dims}d'
	// existing
	existing_idx := t.type_idxs[name]
	if existing_idx > 0 {
		return existing_idx, name
	}
	// register
	idx := t.types.len
	mut array_type := types.Type{}
	array_type = types.Array{
		idx: idx
		name: name
		elem_type_idx: elem_ti.type_idx
		elem_is_ptr: elem_ti.is_ptr()
		nr_dims: nr_dims
	}
	t.type_idxs[name] = idx
	t.types << array_type
	return idx, name
}

pub fn (t mut Table) find_or_register_array_fixed(elem_ti &types.TypeIdent, size int, nr_dims int) (int, string) {
	name := 'array_fixed_${elem_ti.type_name}_${size}_${nr_dims}d'
	// existing
	existing_idx := t.type_idxs[name]
	if existing_idx > 0 {
		return existing_idx, name
	}
	// register
	idx := t.types.len
	mut array_fixed_type := types.Type{}
	array_fixed_type = types.ArrayFixed{
		idx: idx
		name: name
		elem_type_idx: elem_ti.type_idx
		elem_is_ptr: elem_ti.is_ptr()
		size: size
		nr_dims: nr_dims
	}
	t.type_idxs[name] = idx
	t.types << array_fixed_type
	return idx, name
}

pub fn (t mut Table) find_or_register_multi_return(mr_tis []&types.TypeIdent) (int, string) {
	mut name := 'multi_return'
	mut mr_type_kinds := []types.Kind
	mut mr_type_idxs := []int
	for mr_ti in mr_tis {
		name += '_$mr_ti.type_name'
		mr_type_kinds << mr_ti.type_kind
		mr_type_idxs << mr_ti.type_idx
	}
	// existing
	existing_idx := t.type_idxs[name]
	if existing_idx > 0 {
		return existing_idx, name
	}
	// register
	idx := t.types.len
	mut mr_type := types.Type{}
	mr_type = types.MultiReturn{
		idx: idx
		name: name
		type_kinds: mr_type_kinds
		type_idxs: mr_type_idxs
	}
	t.type_idxs[name] = idx
	t.types << mr_type
	return idx, name
}

pub fn (t mut Table) add_placeholder_type(name string) int {
	idx := t.types.len
	t.type_idxs[name] = t.types.len
	mut pt := types.Type{}
	pt = types.Placeholder{
		idx: idx
		name: name
	}
	println('added placeholder: $name - $idx ')
	t.types << pt
	return idx
}
