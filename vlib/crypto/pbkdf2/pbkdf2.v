module pbkdf2

import crypto.hmac
import crypto.sha256
import crypto.sha512
import hash


pub fn key(password []u8, salt []u8, count int, key_length int, h hash.Hash) ![]u8 {
	mut fun := fn(b []u8) []u8 {
		return []u8{}
	}
	mut block_size := 0
	mut size := 0
	match h {
		sha256.Digest {
			fun = sha256.sum256
			block_size = sha256.block_size
			size = sha256.size
		}
		sha512.Digest {
			fun = sha512.sum512
			block_size = sha512.block_size
			size = sha512.size
		}
		else {
			panic("Unsupported hash")
		}
	}

	hash_length := size
	block_count := (key_length + hash_length - 1) / hash_length
	mut output := []u8{}
	mut last := []u8{}
	mut buf := []u8{len: 4, init: 0}
	for i := 1; i <= block_count; i++ {
		last << salt

		buf[0] = u8(i >> 24)
		buf[1] = u8(i >> 16)
		buf[2] = u8(i >> 8)
		buf[3] = u8(i)

		last << buf
		mut xorsum := hmac.new(  password, last,  fun, block_size)
		mut last_hash := xorsum.clone()
		for j := 1; j < count; j++ {
			last_hash = hmac.new( password,last_hash,  fun, block_size)
			for k in 0 .. xorsum.len {
				xorsum[k] ^= last_hash[k]
			}
		}
		output << xorsum
	}
	return output[..key_length]
}
