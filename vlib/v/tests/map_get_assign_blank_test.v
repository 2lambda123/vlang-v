type Abc = string | int

fn test_map_get_assign_blank() {
	x := map[string]Abc{}
	_ := x['nonexisting']
	if y := x['nonexisting'] {
		println(y)
	}
	assert true
}
