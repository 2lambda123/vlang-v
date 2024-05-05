import os

fn test_join_path() {
	assert os.join_path('', '', '') == ''
	assert os.join_path('', '') == ''
	assert os.join_path('') == ''
	assert os.join_path('b', '', '') == 'b'
	assert os.join_path('b', '') == 'b'
	assert os.join_path('b') == 'b'
	assert os.join_path('', '', './b') == 'b'
	assert os.join_path('', '', '/b') == 'b'
	assert os.join_path('', '', 'b') == 'b'
	assert os.join_path('', './b') == 'b'
	assert os.join_path('', '/b') == 'b'
	assert os.join_path('', 'b') == 'b'
	assert os.join_path('b', '') == 'b'
	$if windows {
		assert os.join_path('./b', '') == r'.\b'
		assert os.join_path('/b', '') == r'\b'
		assert os.join_path('v', 'vlib', 'os') == r'v\vlib\os'
		assert os.join_path('', 'f1', 'f2') == r'f1\f2'
		assert os.join_path('v', '', 'dir') == r'v\dir'
		assert os.join_path('foo\\bar', '.\\file.txt') == r'foo\bar\file.txt'
		assert os.join_path('/opt/v', './x') == r'\opt\v\x'
	} $else {
		assert os.join_path('./b', '') == './b'
		assert os.join_path('/b', '') == '/b'
		assert os.join_path('v', 'vlib', 'os') == 'v/vlib/os'
		assert os.join_path('/foo/bar', './file.txt') == '/foo/bar/file.txt'
		assert os.join_path('', 'f1', 'f2') == 'f1/f2'
		assert os.join_path('v', '', 'dir') == 'v/dir'
		assert os.join_path('/', 'test') == '/test'
		assert os.join_path('foo/bar', './file.txt') == 'foo/bar/file.txt'
		assert os.join_path('/opt/v', './x') == '/opt/v/x'
		assert os.join_path('./a', './b') == './a/b'
	}
}

fn test_join_path_single() {
	assert os.join_path_single('', '') == ''
	assert os.join_path_single('', './b') == 'b'
	assert os.join_path_single('', '/b') == 'b'
	assert os.join_path_single('', 'b') == 'b'
	assert os.join_path_single('b', '') == 'b'
	$if windows {
		assert os.join_path_single('./b', '') == r'.\b'
		assert os.join_path_single('/b', '') == r'\b'
		assert os.join_path_single('/foo/bar', './file.txt') == r'\foo\bar\file.txt'
		assert os.join_path_single('/', 'test') == r'\test'
		assert os.join_path_single('foo\\bar', '.\\file.txt') == r'foo\bar\file.txt'
		assert os.join_path_single('/opt/v', './x') == r'\opt\v\x'
	} $else {
		assert os.join_path_single('./b', '') == r'./b'
		assert os.join_path_single('/b', '') == r'/b'
		assert os.join_path_single('/foo/bar', './file.txt') == '/foo/bar/file.txt'
		assert os.join_path_single('/', 'test') == '/test'
		assert os.join_path_single('foo/bar', './file.txt') == 'foo/bar/file.txt'
		assert os.join_path_single('/opt/v', './x') == '/opt/v/x'
		assert os.join_path_single('./a', './b') == './a/b'
		assert os.join_path_single('a', './b') == 'a/b'
	}
}
