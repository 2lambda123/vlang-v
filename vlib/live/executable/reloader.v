module executable

import os
import time
import dl
import strconv
import live

// The live reloader code is implemented here.

// NB: new_live_reload_info will be called by generated C code inside main()
pub fn new_live_reload_info(original string, vexe string, vopts string, live_fn_mutex voidptr, live_linkfn live.FNLinkLiveSymbols) &live.LiveReloadInfo {
	file_base := os.file_name(original).replace('.v', '')
	so_dir := os.cache_dir()
	so_extension := dl.dl_ext
	/* $if msvc { so_extension = '.dll' } $else { so_extension = '.so' } */
	return &live.LiveReloadInfo{
		original: original
		vexe: vexe
		vopts: vopts
		live_fn_mutex: live_fn_mutex
		live_linkfn: live_linkfn
		so_extension: so_extension
		so_name_template: '${so_dir}/tmp.%d.${file_base}'
		live_lib: 0
		reloads: 0
		reload_time_ms: 0
	}
}

// NB: start_reloader will be called by generated code inside main(), to start
// the hot code reloader thread. start_reloader is executed in the context of
// the original main thread.
pub fn start_reloader(r mut live.LiveReloadInfo) {
	// The shared library should be loaded once in the main thread
	// If that fails, the program would crash anyway, just provide
	// an error message to the user and exit:
    r.reloads++
	_ := compile_and_reload_shared_lib(r) or {
		eprintln( err )
		exit(1)
	}
	go reloader(r)
}

[if debuglive]
fn elog(r mut live.LiveReloadInfo, s string){
	eprintln(s)
}

fn compile_and_reload_shared_lib(r mut live.LiveReloadInfo) ?bool {
	sw := time.new_stopwatch()
	new_lib_path := compile_lib(r) or {
		return error('errors while compiling $r.original')
	}
	elog(r,'> compile_and_reload_shared_lib compiled: ${new_lib_path}')
	load_lib(r, new_lib_path )
	r.reload_time_ms = sw.elapsed().milliseconds()
	return true
}

fn compile_lib(r mut live.LiveReloadInfo) ?string {
	new_lib_path, new_lib_path_with_extension := current_shared_library_path(r)
	cmd := '$r.vexe $r.vopts -o $new_lib_path $r.original'
	elog(r,'>       compilation cmd: $cmd')
	cwatch := time.new_stopwatch()
	recompilation_result := os.exec( cmd ) or {
		eprintln('recompilation failed')
		return none
	}
	elog(r,'compilation took: ${cwatch.elapsed().milliseconds()}ms')
	if recompilation_result.exit_code != 0 {
		eprintln('recompilation error:')
		eprintln( recompilation_result.output )
		return none
	}
	if !os.exists( new_lib_path_with_extension ) {
		eprintln('new_lib_path: $new_lib_path_with_extension does not exist')
		return none
	}
	return new_lib_path_with_extension
}

fn current_shared_library_path(r mut live.LiveReloadInfo) (string, string) {
	lib_path := strconv.v_sprintf(r.so_name_template.replace('\\', '\\\\'), r.reloads)
	lib_path_with_extension := lib_path + r.so_extension
	return lib_path, lib_path_with_extension
}

fn load_lib(r mut live.LiveReloadInfo, new_lib_path string) {
	elog(r,'live mutex locking...')
	C.pthread_mutex_lock(r.live_fn_mutex)
	elog(r,'live mutex locked')
	//
	if r.cb_locked_before != 0 {
		r.cb_locked_before( r )
	}
	//
	protected_load_lib(r, new_lib_path)
	//
	r.reloads_ok++
	if r.cb_locked_after != 0 {
		r.cb_locked_after( r )
	}
	//
	elog(r,'live mutex unlocking...')
	C.pthread_mutex_unlock(r.live_fn_mutex)
	elog(r,'live mutex unlocked')
}

fn protected_load_lib(r mut live.LiveReloadInfo, new_lib_path string) {
	if r.live_lib != 0 {
		dl.close( r.live_lib )
		r.live_lib = 0
	}
	r.live_lib = dl.open(new_lib_path, dl.rtld_lazy)
	if r.live_lib == 0 {
		eprintln('opening $new_lib_path failed')
		exit(1)
	}
	r.live_linkfn( r.live_lib )
	elog(r,'> load_lib OK, new live_lib: $r.live_lib')
	// removing the .so file from the filesystem after dlopen-ing
    // it is safe, since it will still be mapped in memory
	os.rm( new_lib_path )
}

// NB: r.reloader() is executed in a new, independent thread
fn reloader(r mut live.LiveReloadInfo) {
//	elog(r,'reloader, r: $r')
	mut last_ts := os.file_last_mod_unix( r.original )
	for {
		if r.cb_recheck != 0 {
			r.cb_recheck( r )
		}
		now_ts := os.file_last_mod_unix( r.original )
		if last_ts != now_ts {
			r.reloads++
			last_ts = now_ts
			r.last_mod_ts = last_ts
			if r.cb_before != 0 {
				r.cb_before( r )
			}
			compile_and_reload_shared_lib(r) or {
				if r.cb_compile_failed != 0 {
					r.cb_compile_failed( r )
				}
				if r.cb_after != 0 {
					r.cb_after( r )
				}
				continue
			}
			if r.cb_after != 0 {
				r.cb_after( r )
			}
		}
		if r.recheck_period_ms > 0 {
			time.sleep_ms(r.recheck_period_ms)
		}
	}
}
