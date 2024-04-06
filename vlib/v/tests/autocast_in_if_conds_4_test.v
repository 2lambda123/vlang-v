type MySumType = S1 | S2

struct Info {
	name string
}

struct S1 {
	is_info bool
	info    Info
}

struct S2 {
	field2 string
}

fn get_name(s1 S1) string {
	return s1.info.name
}

fn test_autocast_in_if_conds() {
	s := MySumType(S1{
		is_info: false
		info: Info{'foo'}
	})

	if s is S1 && !s.is_info && get_name(s) == 'foo' {
		println('ok')
		assert true
	} else {
		assert false
	}
}
