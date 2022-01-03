import os

fn interpreter_wrap(a string) string {
	return 'fn main() {$a}'
}

fn interp_test(expression string, expected string) ? {
	tmpdir := os.temp_dir()
	tmpfile := '$tmpdir/input.v'
	outfile := '$tmpdir/output.txt'
	defer {
		os.rm(tmpfile) or {}
		os.rm(outfile) or {}
		os.rmdir_all(tmpdir) or {}
	}
	os.write_file(tmpfile, interpreter_wrap(expression)) ?
	if os.system('v interpret $tmpfile > $outfile') != 0 {
		return error('v interp')
	}
	res := os.read_file(outfile) ?
	if res.trim_space() != expected {
		return error('test')
	}
}

struct InterpTest {
	input  string
	output string
}

fn test_interpreter() ? {
	mut tests := []InterpTest{}
	tests << InterpTest{'println(3+3)', '6'}
	tests << InterpTest{'println(3)', '3'}
	tests << InterpTest{'println(3-4)', '-1'}
	tests << InterpTest{'println(3*3)', '9'}
	tests << InterpTest{'a:= 3\nprintln(a*3)', '9'}
	for test in tests {
		interp_test(test.input, test.output) ?
	}
}
