fn test_struct_definition_inside_fn() {
	struct App {
		name string
	}
	assert App{"make"}.name == "make"
}