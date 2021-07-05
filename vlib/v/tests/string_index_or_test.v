fn test_empty_string_access() {
	mut res := ''
	a := ''
	if a[0] or { `0` } == `1` {
		res = 'good'
	} else {
		res = 'bad'
	}
	assert res == 'bad'
}

fn test_good_string_access() {
	mut res := ''
	a := 'abcd'
	if a[2] or { `0` } == `c` {
		res = 'good'
	} else {
		res = 'bad'
	}
	assert res == 'good'
}

fn test_if_guard_bad() {
	mut res := 'bad'
	a := 'xy'
	if z := a[2] {
		res = '${z:c}'
	}
	assert res == 'bad'
}

fn test_if_guard_good() {
	mut res := 'bad'
	a := 'xy123'
	if z := a[2] {
		res = '${z:c}'
	}
	assert res == '1'
}
