module arrays


fn test_min() {
	a := [8, 2, 6, 4]
	assert min<int>(a)==2
	assert min<int>(a[2..])==4
	
	b := [f32(5.1), 3.1, 1.1, 9.1]
	assert min<f32>(b) == f32(1.1)
	assert min<f32>(b[..2]) == f32(3.1)
	
	c := [byte(4), 9, 3, 1]
	assert min<byte>(c) == byte(1)
	assert min<byte>(c[..3]) == byte(3)
}


fn test_max() {
	a := [8, 2, 6, 4]
	assert max<int>(a)==8
	assert max<int>(a[1..])==6
	
	b := [f32(5.1), 3.1, 1.1, 9.1]
	assert max<f32>(b) == f32(9.1)
	assert max<f32>(b[..3]) == f32(5.1)
	
	c := [byte(4), 9, 3, 1]
	assert max<byte>(c) == byte(9)
	assert max<byte>(c[2..]) == byte(3)
}


fn test_idxmin() {
	a := [8, 2, 6, 4]
	assert idxmin<int>(a)==1
	
	b := [f32(5.1), 3.1, 1.1, 9.1]
	assert idxmin<f32>(b) == 2
	
	c := [byte(4), 9, 3, 1]
	assert idxmin<byte>(c) == 3
}


fn test_idxmax() {
	a := [8, 2, 6, 4]
	assert idxmax<int>(a)==0
	
	b := [f32(5.1), 3.1, 1.1, 9.1]
	assert idxmax<f32>(b) == 3
	
	c := [byte(4), 9, 3, 1]
	assert idxmax<byte>(c) == 1
}


fn test_shuffle() {
	a := [1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20]
	mut b := a.clone()
	mut c := a.clone()
	shuffle<int>(mut b, 0)
	shuffle<int>(mut c, 0)
	assert a != b // false negative chance: 1/20!
	assert a != c // false negative chance: 1/20!
	assert b != c // false negative chance: 1/20!
	
	// test shuffling a slice
	mut d := a.clone()
	shuffle<int>(mut d[..15], 0)
	assert d[..15] != a[..15] // false negative chance: 1/15!
	assert d[15..] == a[15..]
	
	// test shuffling n items
	mut e := a.clone()
	shuffle<int>(mut e, 15)
	assert e[..15] != a[..15] // false negative chance: 1/15!
	assert e[15..] != a[15..] // false negative chance: TODO
	
	// test shuffling empty array
	mut f := a.clone()
	f.trim(0)
	shuffle<int>(mut f,0)
}

fn test_merge() {
	a := [1,3,5,5,7]
	b := [2,4,4,5,6,8]
	c := []int{}
	d := []int{}
	assert merge<int>(a,b) == [1,2,3,4,4,5,5,5,6,7,8]
	assert merge<int>(c,d) == []
	assert merge<int>(a,c) == a
	assert merge<int>(d,b) == b
}
