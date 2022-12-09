import x.json2 as json
import time

enum JobTitle {
	manager
	executive
	worker
}

struct Employee {
pub mut:
	name   string
	age    int
	salary f32
	title  JobTitle
}

struct OptionalStruct {
pub mut:
	name      string
	last_name ?string = none
	age       ?int    = none
	salary    ?f32    = none
}

fn test_simple_optional() {
	x := OptionalStruct{
		name: 'Peter'
	}
	s := json.encode[OptionalStruct](x)
	assert s == '{"name":"Peter"}'
	// y := json.decode<EmployeeOp>(s) or {
	// 	println(err)
	// 	assert false
	// 	return
	// }
	// assert y.name == 'Peter'
	// assert y.age == 28
	// assert y.salary == 95000.5
	// assert y.title == .worker
}

// ! BUGFIX
// fn test_simplegg() {
// 	// x := EmployeeOp{'Peter', 28, 95000.5, .worker}
// 	x := EmployeeOp{
// 		name: 'vshfvhsd'
// 	}
// 	s := json.encode<EmployeeOp>(x)
// 	assert s == '{"name":"vshfvhsd","age":0,"salary":0.0,"title":0.0}'
// 	// y := json.decode<EmployeeOp>(s) or {
// 	// 	println(err)
// 	// 	assert false
// 	// 	return
// 	// }
// 	// assert y.name == 'Peter'
// 	// assert y.age == 28
// 	// assert y.salary == 95000.5
// 	// assert y.title == .worker
// }

fn test_fast_raw_decode() {
	s := '{"name":"Peter","age":28,"salary":95000.5,"title":2}'
	o := json.fast_raw_decode(s) or {
		assert false
		json.Any(json.null)
	}
	str := o.str()
	assert str == '{"name":"Peter","age":"28","salary":"95000.5","title":"2"}'
}

fn test_character_unescape() {
	message := r'{
	"newline": "new\nline",
	"tab": "\ttab",
	"backslash": "back\\slash",
	"quotes": "\"quotes\"",
	"slash":"\/dev\/null"
}'
	mut obj := json.raw_decode(message) or {
		println(err)
		assert false
		return
	}
	lines := obj.as_map()
	assert lines['newline'] or { 0 }.str() == 'new\nline'
	assert lines['tab'] or { 0 }.str() == '\ttab'
	assert lines['backslash'] or { 0 }.str() == 'back\\slash'
	assert lines['quotes'] or { 0 }.str() == '"quotes"'
	assert lines['slash'] or { 0 }.str() == '/dev/null'
}

struct MultTypeTest[T] {
mut:
	val T
}

struct MultTypeTestOptional[T] {
mut:
	val ?T
}

// NOTE - This can substitute a lot of others tests
fn test_mult_decode() {
	assert json.decode[MultTypeTest[bool]]('{"val": ""}')!.val == false
	assert json.decode[MultTypeTest[bool]]('{"val": "0"}')!.val == false
	assert json.decode[MultTypeTest[bool]]('{"val": "1"}')!.val == true
	assert json.decode[MultTypeTest[bool]]('{"val": "2"}')!.val == true
	assert json.decode[MultTypeTest[bool]]('{"val": 0}')!.val == false
	assert json.decode[MultTypeTest[bool]]('{"val": 1}')!.val == true
	assert json.decode[MultTypeTest[bool]]('{"val": 2}')!.val == true
	assert json.decode[MultTypeTest[bool]]('{"val": "true"}')!.val == true
	assert json.decode[MultTypeTest[bool]]('{"val": "false"}')!.val == false
	assert json.decode[MultTypeTest[bool]]('{"val": true}')!.val == true
	assert json.decode[MultTypeTest[bool]]('{"val": false}')!.val == false

	assert json.decode[MultTypeTest[int]]('{"val": ""}')!.val == 0
	assert json.decode[MultTypeTest[int]]('{"val": "0"}')!.val == 0
	assert json.decode[MultTypeTest[int]]('{"val": "1"}')!.val == 1
	assert json.decode[MultTypeTest[int]]('{"val": "2"}')!.val == 2
	assert json.decode[MultTypeTest[int]]('{"val": 0}')!.val == 0
	assert json.decode[MultTypeTest[int]]('{"val": 1}')!.val == 1
	assert json.decode[MultTypeTest[int]]('{"val": 2}')!.val == 2
	assert json.decode[MultTypeTest[int]]('{"val": "true"}')!.val == 1
	assert json.decode[MultTypeTest[int]]('{"val": "false"}')!.val == 0
	assert json.decode[MultTypeTest[int]]('{"val": true}')!.val == 1
	assert json.decode[MultTypeTest[int]]('{"val": false}')!.val == 0

	assert json.decode[MultTypeTest[string]]('{"val": ""}')!.val == ''
	assert json.decode[MultTypeTest[string]]('{"val": "0"}')!.val == '0'
	assert json.decode[MultTypeTest[string]]('{"val": "1"}')!.val == '1'
	assert json.decode[MultTypeTest[string]]('{"val": "2"}')!.val == '2'
	assert json.decode[MultTypeTest[string]]('{"val": 0}')!.val == '0'
	assert json.decode[MultTypeTest[string]]('{"val": 1}')!.val == '1'
	assert json.decode[MultTypeTest[string]]('{"val": 2}')!.val == '2'
	assert json.decode[MultTypeTest[string]]('{"val": "true"}')!.val == 'true'
	assert json.decode[MultTypeTest[string]]('{"val": "false"}')!.val == 'false'
	assert json.decode[MultTypeTest[string]]('{"val": true}')!.val == 'true'
	assert json.decode[MultTypeTest[string]]('{"val": false}')!.val == 'false'

	// assert json.decode[MultTypeTestOptional[string]]('{"val": ""}')! == MultTypeTestOptional[string]{val: ""}
	/*
	assert json.decode[MultTypeTestOptional[string]]('{"val": "0"}')!.val == "0"
	assert json.decode[MultTypeTestOptional[string]]('{"val": "1"}')!.val == "1"
	assert json.decode[MultTypeTestOptional[string]]('{"val": "2"}')!.val == "2"
	assert json.decode[MultTypeTestOptional[string]]('{"val": 0}')!.val == "0"
	assert json.decode[MultTypeTestOptional[string]]('{"val": 1}')!.val == "1"
	assert json.decode[MultTypeTestOptional[string]]('{"val": 2}')!.val == "2"
	assert json.decode[MultTypeTestOptional[string]]('{"val": "true"}')!.val == "true"
	assert json.decode[MultTypeTestOptional[string]]('{"val": "false"}')!.val == "false"
	assert json.decode[MultTypeTestOptional[string]]('{"val": true}')!.val == "true"
	assert json.decode[MultTypeTestOptional[string]]('{"val": false}')!.val == "false"
	*/
}

fn test_mult_encode() {
	assert json.encode(MultTypeTest[[]string]{}) == '{"val":[]}'
	assert json.encode(MultTypeTest[[]string]{ val: [] }) == '{"val":[]}'
	assert json.encode(MultTypeTest[[]string]{ val: ['0'] }) == '{"val":["0"]}'
	assert json.encode(MultTypeTest[[]string]{ val: ['1'] }) == '{"val":["1"]}'

	assert json.encode(MultTypeTest[bool]{}) == '{"val":false}'
	assert json.encode(MultTypeTest[bool]{ val: false }) == '{"val":false}'
	assert json.encode(MultTypeTest[bool]{ val: true }) == '{"val":true}'

	assert json.encode(MultTypeTestOptional[bool]{ val: none }) == '{}'
	assert json.encode(MultTypeTestOptional[bool]{}) == '{"val":false}'
	assert json.encode(MultTypeTestOptional[bool]{ val: false }) == '{"val":false}'
	assert json.encode(MultTypeTestOptional[bool]{ val: true }) == '{"val":true}'

	assert json.encode(MultTypeTest[int]{}) == '{"val":0}'
	assert json.encode(MultTypeTest[int]{ val: 0 }) == '{"val":0}'
	assert json.encode(MultTypeTest[int]{ val: 1 }) == '{"val":1}'

	assert json.encode(MultTypeTestOptional[int]{ val: none }) == '{}'
	assert json.encode(MultTypeTestOptional[int]{}) == '{"val":0}'
	assert json.encode(MultTypeTestOptional[int]{ val: 0 }) == '{"val":0}'
	assert json.encode(MultTypeTestOptional[int]{ val: 1 }) == '{"val":1}'

	assert json.encode(MultTypeTest[[]int]{}) == '{"val":[]}'
	assert json.encode(MultTypeTest[[]int]{ val: [] }) == '{"val":[]}'
	assert json.encode(MultTypeTest[[]int]{ val: [0] }) == '{"val":[0]}'
	assert json.encode(MultTypeTest[[]int]{ val: [1] }) == '{"val":[1]}'
	assert json.encode(MultTypeTest[[]int]{ val: [0, 1, 0, 2, 3, 2, 5, 1] }) == '{"val":[0,1,0,2,3,2,5,1]}'

	assert json.encode(MultTypeTestOptional[[]int]{ val: none }) == '{}'
	assert json.encode(MultTypeTestOptional[[]int]{}) == '{"val":[]}'
	assert json.encode(MultTypeTestOptional[[]int]{ val: [] }) == '{"val":[]}'
	assert json.encode(MultTypeTestOptional[[]int]{ val: [0] }) == '{"val":[0]}'
	assert json.encode(MultTypeTestOptional[[]int]{ val: [1] }) == '{"val":[1]}'
	assert json.encode(MultTypeTestOptional[[]int]{ val: [0, 1, 0, 2, 3, 2, 5, 1] }) == '{"val":[0,1,0,2,3,2,5,1]}'

	assert json.encode(MultTypeTest[[]byte]{}) == '{"val":[]}'
	assert json.encode(MultTypeTest[[]byte]{ val: [] }) == '{"val":[]}'
	assert json.encode(MultTypeTest[[]byte]{ val: [byte(0)] }) == '{"val":[0]}'
	assert json.encode(MultTypeTest[[]byte]{ val: [byte(1)] }) == '{"val":[1]}'
	assert json.encode(MultTypeTest[[]byte]{ val: [byte(0), 1, 0, 2, 3, 2, 5, 1] }) == '{"val":[0,1,0,2,3,2,5,1]}'

	assert json.encode(MultTypeTest[[]i64]{}) == '{"val":[]}'
	assert json.encode(MultTypeTest[[]i64]{ val: [] }) == '{"val":[]}'
	assert json.encode(MultTypeTest[[]i64]{ val: [i64(0)] }) == '{"val":[0]}'
	assert json.encode(MultTypeTest[[]i64]{ val: [i64(1)] }) == '{"val":[1]}'
	assert json.encode(MultTypeTest[[]i64]{ val: [i64(0), 1, 0, 2, 3, 2, 5, 1] }) == '{"val":[0,1,0,2,3,2,5,1]}'

	assert json.encode(MultTypeTest[[]u64]{}) == '{"val":[]}'
	assert json.encode(MultTypeTest[[]u64]{ val: [] }) == '{"val":[]}'
	assert json.encode(MultTypeTest[[]u64]{ val: [u64(0)] }) == '{"val":[0]}'
	assert json.encode(MultTypeTest[[]u64]{ val: [u64(1)] }) == '{"val":[1]}'
	assert json.encode(MultTypeTest[[]u64]{ val: [u64(0), 1, 0, 2, 3, 2, 5, 1] }) == '{"val":[0,1,0,2,3,2,5,1]}'

	assert json.encode(MultTypeTest[[]f64]{}) == '{"val":[]}'
	assert json.encode(MultTypeTest[[]f64]{ val: [] }) == '{"val":[]}'
	assert json.encode(MultTypeTest[[]f64]{ val: [f64(0)] }) == '{"val":[0.0]}'
	assert json.encode(MultTypeTest[[]f64]{ val: [f64(1)] }) == '{"val":[1.0]}'
	assert json.encode(MultTypeTest[[]f64]{ val: [f64(0), 1, 0, 2, 3, 2, 5, 1] }) == '{"val":[0.0,1.0,0.0,2.0,3.0,2.0,5.0,1.0]}'

	assert json.encode(MultTypeTest[[]bool]{}) == '{"val":[]}'
	assert json.encode(MultTypeTest[[]bool]{ val: [] }) == '{"val":[]}'
	assert json.encode(MultTypeTest[[]bool]{ val: [true] }) == '{"val":[true]}'
	assert json.encode(MultTypeTest[[]bool]{ val: [false] }) == '{"val":[false]}'
	assert json.encode(MultTypeTest[[]bool]{ val: [false, true, false] }) == '{"val":[false,true,false]}'
}
