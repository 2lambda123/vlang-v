typedef enum {
	Color_red, // 0
	Color_green, // 1
	Color_blue, // 2
} Color;

struct Two {
};

struct User {
	int age;
};

struct One {
	Two two;
};

// multi return structs
typedef struct {
	int arg0;
	string arg1;
} multi_return_int_string;
// end of definitions #endif
#define _const_pi 3
int _const_pi2; // inited later
void foo(int a);
void User_inc_age(User* u, int n);
int get_int(string a);
bool get_bool();
int get_int2();
void myuser();
multi_return_int_string multi_return();
void variadic(varg_int a);
void ensure_cap(int required, int cap);
void println(string s);
void matches();
#define _const_path_sep 10
void end();
#define _const_localmod__pub_int_const 20
void localmod__pub_foo();
int localmod__get_int_10();
// variadic structs
struct varg_int {
	int len;
	int args[0];
};

//
int main(int argc, char** argv) {
	_vinit();
	int a = 10;
	a++;
	int negative = -a;
	2 < 3;
	a == 1;
	a++;
	foo(3);
	int ak = 10;
	int mypi = _const_pi;
	Color color = Color_red;
	localmod__pub_foo();
	int ten = localmod__get_int_10();
	println(int_str(_const_localmod__pub_int_const));
	int g = ((int)(3.0));
	byte* bytes = ((byte*)(0));
    User* user_ptr = (User*)memdup(&(User){	.age = 0,
}, sizeof(User));
	return 0;
}

void foo(int a) {
	while (true) {
	}
	for (int i = 0;
i < 10; i++) {
	}
	array_int nums = new_array_from_c_array(3, 3, sizeof(int), (int[3]){
		1, 2, 3,
	});
	array_int nums2 = array_slice(nums, 0, 2);
	array_int nums3 = array_slice(nums, 1, 2);
	array_int nums4 = array_slice(nums, 1, nums.len);
	int number = (*(int*)array_get(nums, 0));
	array_set(&nums, 1, &(int[]) { 10 });
	array_bool bools = new_array_from_c_array(2, 2, sizeof(bool), (bool[2]){
		true, false,
	});
	array_User users = new_array_from_c_array(1, 1, sizeof(User), (User[1]){
		(User){
			.age = 0,
		},
	});
	bool b = (*(bool*)array_get(bools, 0));
	array_string mystrings = new_array_from_c_array(2, 2, sizeof(string), (string[2]){
		tos3("a"), tos3("b"),
	});
	string s = (*(string*)array_get(mystrings, 0));
	int x = 0;
	x = get_int2();
	int n = get_int2();
	bool q = true || false;
	bool b2 = (*(bool*)array_get(bools, 0)) || true;
	bool b3 = get_bool() || true;
	int f = *(int*)array_first(nums);
	array_int c = array_clone(&nums);
	string d = tos3("d");
	println(string_add(s, d));
}

void User_inc_age(User* u, int n) {
	printf("%d", u->age);
	u->age += n;
}

int get_int(string a) {
	return 10;
}

bool get_bool() {
	return true;
}

int get_int2() {
	string a = tos3("hello");
	return get_int(a);
}

void myuser() {
	int x = 1;
	int q = x | 4100;
	User user = (User){
		.age = 30,
	};
	int age = user.age + 1;
	int boo = 2;
	int boo2 = boo + 1;
	bool b = age > 0;
	bool b2 = user.age > 0;
	User user2 = (User){
		.age = 20,
	};
	user2.age = 20 + boo;
}

multi_return_int_string multi_return() {
	return (multi_return_int_string){.arg0=4,.arg1=tos3("four")};
}

void variadic(varg_int a) {
	int x = _const_path_sep;
	int y = true ? 1 : 0;
}

void ensure_cap(int required, int cap) {
	if (required < cap) {
		return;
	}
}

void println(string s) {
}

void matches() {
	int a = 100;
	if (a == 10) {
		println(tos3("10"));
	}
	else if (a == 20) {
		int k = a + 1;
	}
	else {
	}
	;
	string x = (a == 10) ? tos3("ten") : (a == 30) ? tos3("thirty") : tos3("unknown");
	int xx = (a == 10) ? 100 : (a == 30) ? 300 : 0;
	println((a == 10) ? tos3("ten") : tos3("not ten"));
}

void end() {
	int i = 2;
	int key = 10;
	bool x = i != -1 && key == 10;
	int e = 2 + 3 * 4;
}

void localmod__pub_foo() {
	int a = 10;
}

int localmod__get_int_10() {
	return 10;
}

void _vinit() {
	_const_pi2 = _const_pi;
}


