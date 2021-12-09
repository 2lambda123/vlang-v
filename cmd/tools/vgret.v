// Copyright (c) 2021 Lars Pontoppidan. All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.
//
// vgret (V Graphics REgression Tool) aids in generating screenshots of various graphical `gg`
// based V applications, in a structured directory hierarchy, with the intent of either:
// * Generate a directory structure of screenshots/images to test against
//   (which, as an example, could later be pushed to a remote git repository)
// * Test for *visual* differences between two, structurally equal, directories
//
// vgret uses features and applications that is currently only available on Linux based distros:
// idiff : `sudo apt install openimageio-tools` to programmatically find *visual* differences between two images.
//
// For developers:
// For a quick overview of the generated images you can use `montage` from imagemagick to generate a "Contact Sheet":
// montage -verbose -label '%f' -font Helvetica -pointsize 10 -background '#000000' -fill 'gray' -define jpeg:size=200x200 -geometry 200x200+2+2 -auto-orient $(fd -t f . /path/to/vgret/out/dir) /tmp/montage.jpg
import os
import flag

const (
	tool_name        = os.file_name(os.executable())
	tool_version     = '0.0.1'
	tool_description = '\n  Dump and/or compare rendered frames of `gg` based apps

Examples:
  Generate screenshots to `/tmp/test`
    v gret /tmp/test
  Generate and compare screenshots in `/tmp/src` to existing screenshots in `/tmp/dst`
    v gret /tmp/src /tmp/dst
  Compare screenshots in `/tmp/src` to existing screenshots in `/tmp/dst`
    v gret --compare-only /tmp/src /tmp/dst
'
	tmp_dir    = os.join_path(os.temp_dir(), 'v', tool_name)
	runtime_os = os.user_os()
	v_root     = os.real_path(@VMODROOT)
	build_list = [
		//'examples/snek/snek.v'
		'examples/game_of_life/life_gg.v'
		//'examples/tetris/tetris.v'
		//'examples/fireworks/fireworks.v'
		'examples/gg/bezier.v',
		'examples/gg/mandelbrot.v',
		'examples/gg/rectangles.v',
		'examples/gg/set_pixels.v'
		//'examples/gg/random.v'
		//'examples/gg/stars.v'
		'examples/gg/raven_text_rendering.v',
		'examples/gg/worker_thread.v',
		'examples/gg/polygons.v',
		'examples/gg/bezier_anim.v',
		'examples/gg/drag_n_drop.v'
		//'examples/clock/clock.v'
		//'examples/hot_reload/bounce.v'
		//'examples/hot_reload/graph.v'
		//'examples/flappylearning/game.v'
		//'examples/2048/2048.v'
		'examples/ttf_font/example_ttf.v'
		//'examples/sokol/06_obj_viewer/show_obj.v'
		//'examples/sokol/04_multi_shader_glsl/rt_glsl.v'
		//'examples/sokol/03_march_tracing_glsl/rt_glsl.v'
		//'examples/sokol/02_cubes_glsl/cube_glsl.v'
		//'examples/sokol/05_instancing_glsl/rt_glsl.v'
		'examples/sokol/01_cubes/cube.v',
	]
)

const (
	supported_hosts = ['linux']
	// External tool executables
	v_exe           = vexe()
	idiff_exe       = os.find_abs_path_of_executable('idiff') or { '' }
)

struct Options {
	show_help    bool
	verbose      bool
	compare_only bool
}

fn main() {
	if os.args.len == 1 {
		println('Usage: $tool_name PATH \n$tool_description\n$tool_name -h for more help...')
		exit(1)
	}
	mut fp := flag.new_flag_parser(os.args[1..])
	fp.application(tool_name)
	fp.version(tool_version)
	fp.description(tool_description)
	fp.arguments_description('PATH [PATH]')
	fp.skip_executable()
	// Collect tool options
	opt := Options{
		show_help: fp.bool('help', `h`, false, 'Show this help text.')
		verbose: fp.bool('verbose', `v`, false, "Be verbose about the tool's progress.")
		compare_only: fp.bool('compare-only', `c`, false, "Don't generate screenshots - only compare input directories")
	}
	if opt.show_help {
		println(fp.usage())
		exit(0)
	}

	ensure_env(opt) or { panic(err) }

	arg_paths := fp.finalize() or { panic(err) }

	if arg_paths.len == 0 {
		println(fp.usage())
		println('Error missing arguments')
		exit(1)
	}
	if arg_paths.len == 1 {
		generate_screenshots(opt, v_root, arg_paths[0]) ?
	} else if arg_paths.len > 1 {
		compare_screenshots(opt, v_root, arg_paths[0], arg_paths[1]) or { panic(err) }
	}
}

fn generate_screenshots(opt Options, base_path string, output_path string) ?[]string {
	mut path := os.real_path(base_path)
	path = path.trim_right('/')

	dst_path := output_path.trim_right('/')

	if !os.is_dir(path) {
		return error('`$path` is not a directory')
	}

	mut screenshots := []string{}

	for file in build_list {
		app_path := os.join_path(path, file).trim_right('/')

		mut rel_out_path := ''
		if os.is_file(app_path) {
			rel_out_path = os.dir(file.trim_right('/'))
		} else {
			rel_out_path = file.trim_right('/')
		}

		if opt.verbose {
			eprintln('Compiling shaders (if needed) for `$file`')
		}
		sh_result := os.execute('$v_exe shader "$app_path"')
		if sh_result.exit_code != 0 {
			if opt.verbose {
				eprintln('Skipping shader compile for `$file` v shader failed with:\n$sh_result.output')
			}
			continue
		}

		if !os.exists(dst_path) {
			if opt.verbose {
				eprintln('Creating output path `$dst_path`')
			}
			os.mkdir_all(dst_path) ?
		}

		screenshot_path := os.join_path(dst_path, rel_out_path)
		if !os.exists(screenshot_path) {
			os.mkdir_all(screenshot_path) or {
				return error('Failed making screenshot path `$screenshot_path`')
			}
		}

		screenshots << take_screenshots(opt, app_path, screenshot_path) or {
			return error('Failed taking screenshot of `$app_path`:\n$err.msg')
		}
	}
	return screenshots
}

fn compare_screenshots(opt Options, base_path string, output_path string, target_path string) ? {
	if idiff_exe == '' {
		return error('$tool_name need the `idiff` tool installed. It can be installed on Ubuntu with `sudo apt install openimageio-tools`')
	}

	mut path := os.real_path(base_path)
	path = path.trim_right('/')

	if !os.is_dir(path) {
		return error('`$path` is not a directory')
	}
	if !os.is_dir(target_path) {
		return error('`$target_path` is not a directory')
	}
	if path == target_path {
		return error('Compare paths can not be the same directory `$path`')
	}

	screenshots := generate_screenshots(opt, path, output_path) ?

	if opt.verbose {
		eprintln('Comparing $screenshots.len screenshots in `$output_path` with `$target_path`')
	}

	mut fails := map[string]string{}
	for screenshot in screenshots {
		relative_screenshot := screenshot.all_after(output_path + os.path_separator)

		src := screenshot
		target := os.join_path(target_path, relative_screenshot)

		if opt.verbose {
			eprintln('Comparing `$src` with `$target`')
		}

		result := os.execute('$idiff_exe "$src" "$target"')
		if opt.verbose {
			eprintln('$result.output')
		}
		if result.exit_code != 0 {
			fails[src] = target
		}
	}

	if fails.len > 0 {
		eprintln('The following files did not match their targets')
		for fail_src, fail_target in fails {
			eprintln('$fail_src != $fail_target')
		}
		first := fails.keys()[0]
		fail_copy := os.join_path(os.temp_dir(), 'fail.' + first.all_after_last('.'))
		os.cp(first, fail_copy) or { panic(err) }
		eprintln('First failed file `$first` is copied to `$fail_copy`')
		exit(1)
	}
}

fn take_screenshots(opt Options, app string, out_path string) ?[]string {
	if !opt.compare_only {
		if opt.verbose {
			eprintln('Taking screenshot(s) of `$app` to `$out_path`')
		}
		os.setenv('VGG_STOP_AT_FRAME', '8', true)
		os.setenv('VGG_SCREENSHOT_FOLDER', out_path, true)
		os.setenv('VGG_SCREENSHOT_FRAMES', '5', true)
		result := os.execute('$v_exe -d gg_record run "$app"')
		if result.exit_code != 0 {
			return error('Failed taking screenshot of `$app`:\n$result.output')
		}
	}
	mut screenshots := []string{}
	shots := os.ls(out_path) or { return error('Failed listing dir `$out_path`') }
	for shot in shots {
		screenshots << os.join_path(out_path, shot)
	}
	return screenshots
}

// ensure_env returns nothing if everything is okay.
fn ensure_env(opt Options) ? {
	if !os.exists(tmp_dir) {
		os.mkdir_all(tmp_dir) ?
	}

	if runtime_os !in supported_hosts {
		return error('$tool_name is currently only supported on $supported_hosts hosts')
	}
}

// vexe returns the absolute path to the V compiler.
fn vexe() string {
	mut exe := os.getenv('VEXE')
	if os.is_executable(exe) {
		return os.real_path(exe)
	}
	possible_symlink := os.find_abs_path_of_executable('v') or { '' }
	if os.is_executable(possible_symlink) {
		exe = os.real_path(possible_symlink)
	}
	return exe
}
