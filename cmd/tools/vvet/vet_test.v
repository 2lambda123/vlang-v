import os
import term
import v.util.vtest
import v.util

const diff_cmd = find_diff_cmd()

fn find_diff_cmd() string {
	res := util.find_working_diff_command() or { '' }
	return res
}

fn test_vet() {
	vexe := os.getenv('VEXE')
	vroot := os.dir(vexe)
	os.chdir(vroot)
	test_dir := 'cmd/tools/vvet/tests'
	tests := get_tests_in_dir(test_dir)
	fails := check_path(vexe, test_dir, tests)
	assert fails == 0
}

fn get_tests_in_dir(dir string) []string {
	files := os.ls(dir) or { panic(err.msg) }
	mut tests := files.filter(it.ends_with('.vv'))
	tests.sort()
	return tests
}

fn check_path(vexe string, dir string, tests []string) int {
	mut nb_fail := 0
	paths := vtest.filter_vtest_only(tests, basepath: dir)
	for path in paths {
		program := path
		print(path + ' ')
		// -force is needed so that `v vet` would not skip the regression files
		res := os.exec('$vexe vet -force $program') or { panic(err.msg) }
		mut expected := os.read_file(program.replace('.vv', '') + '.out') or { panic(err.msg) }
		expected = clean_line_endings(expected)
		found := clean_line_endings(res.output)
		if expected != found {
			println(term.red('FAIL'))
			println('============')
			println('expected:')
			println(expected)
			println('============')
			println('found:')
			println(found)
			println('============\n')
			println('diff:')
			println(util.color_compare_strings(diff_cmd, found, expected))
			println('============\n')
			nb_fail++
		} else {
			println(term.green('OK'))
		}
	}
	return nb_fail
}

fn clean_line_endings(s string) string {
	mut res := s.trim_space()
	res = res.replace(' \n', '\n')
	res = res.replace(' \r\n', '\n')
	res = res.replace('\r\n', '\n')
	res = res.trim('\n')
	return res
}
