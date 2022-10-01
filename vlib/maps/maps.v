module maps

// filter filters map entries by the given predicate function
pub fn filter<K, V>(m map[K]V, f fn (K, V) bool) map[K]V {
	mut mp := map[K]V{}

	for k, v in m {
		if f(k, v) {
			mp[k] = v
		}
	}

	return mp
}

// flat_map maps map entries into arrays and flattens into a one-dimensional array
pub fn flat_map<K, V, I>(m map[K]V, f fn (K, V) []I) []I {
	mut a := []I{cap: m.len}

	for k, v in m {
		a << f(k, v)
	}

	return a
}

// maps maps map entries into one-dimensional array
pub fn maps<K, V, I>(m map[K]V, f fn (K, V) I) []I {
	mut a := []I{cap: m.len}

	for k, v in m {
		a << f(k, v)
	}

	return a
}
