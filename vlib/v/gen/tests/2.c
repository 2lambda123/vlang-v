int function1() {
	int a = 10 + 1;
	int b = a + 1;
	return 0;
}

void foo(int a) {
}

typedef struct {
	string name;
} User;

void function2() {
	int x = 0;
	f64 f = 10.1;
	string s = tos3("hi");
	int m = 10;
	x += 10;
	x += 1;
	m += 2;
	function1();
	if (true) {
		foo(10);
		x += 8;
	}
	if (false) {
		foo(1);
	}
	while (true) {
		foo(0);
	}
	bool e = 1 + 2 > 0;
	bool e2 = 1 + 2 < 0;
	int j = 0;
}

void init_user() {
	User user = (User){
		.name = tos3("Bob"),
	};
}

void init_array() {
	int nums = new_array_from_c_array(3, 3, sizeof(int), {
		1, 2, 3,
	});
}

int main() {
	return 0;
}


