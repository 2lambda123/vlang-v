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

struct EmployeeOp {
pub mut:
	name      ?string = none
	last_name ?string = none
	age       ?int
	salary    f32
	title     JobTitle
}

fn (e Employee) to_json() string {
	mut mp := map[string]json.Any{}
	mp['name'] = json.Any(e.name)
	mp['age'] = json.Any(e.age)
	mp['salary'] = json.Any(e.salary)
	mp['title'] = json.Any(int(e.title))
	/*
	$for field in Employee.fields {
		d := e.$(field.name)

		$if field.typ is JobTitle {
			mp[field.name] = json.encode<int>(d)
		} $else {
			mp[field.name] = d
		}
	}
	*/
	return mp.str()
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

// NOTE - This can substitute a lot of others tests
fn test_bool_decode() {
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
}
