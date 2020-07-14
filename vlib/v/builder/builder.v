module builder

import os
import v.ast
import v.table
import v.pref
import v.util
import v.vmod
import v.checker
import v.parser
import v.depgraph

pub struct Builder {
pub:
	compiled_dir        string // contains os.real_path() of the dir of the final file beeing compiled, or the dir itself when doing `v .`
	module_path         string
mut:
	checker             checker.Checker
	pref                &pref.Preferences
	global_scope        &ast.Scope
	out_name_c          string
	out_name_js         string
	max_nr_errors       int = 100
pub mut:
	module_search_paths []string
	parsed_files        []ast.File
	cached_msvc			MsvcResult
	table               &table.Table
}

pub fn new_builder(pref &pref.Preferences) Builder {
	rdir := os.real_path(pref.path)
	compiled_dir := if os.is_dir(rdir) { rdir } else { os.dir(rdir) }
	table := table.new_table()
	if pref.use_color == .always {
		util.emanager.set_support_color(true)
	}
	if pref.use_color == .never {
		util.emanager.set_support_color(false)
	}
	msvc := find_msvc() or {
		if pref.ccompiler == 'msvc' {
			verror('Cannot find MSVC on this OS')
		}
		MsvcResult { valid: false }
	}
	return Builder{
		pref: pref
		table: table
		checker: checker.new_checker(table, pref)
		global_scope: &ast.Scope{
			parent: 0
		}
		compiled_dir: compiled_dir
		max_nr_errors: if pref.error_limit > 0 {
			pref.error_limit
		} else {
			100
		}
		cached_msvc: msvc
	}
	// max_nr_errors: pref.error_limit ?? 100 TODO potential syntax?
}

// parse all deps from already parsed files
pub fn (mut b Builder) parse_imports() {
	mut done_imports := []string{}
		if b.pref.is_script {
			done_imports << 'os'
		}
	// NB: b.parsed_files is appended in the loop,
	// so we can not use the shorter `for in` form.
	for i := 0; i < b.parsed_files.len; i++ {
		ast_file := b.parsed_files[i]
		for imp in ast_file.imports {
			mod := imp.mod
			if mod == 'builtin' {
				verror('cannot import module "builtin"')
				break
			}
			if mod in done_imports {
				continue
			}
			import_path := b.find_module_path(mod, ast_file.path) or {
				// v.parsers[i].error_with_token_index('cannot import module "$mod" (not found)', v.parsers[i].import_table.get_import_tok_idx(mod))
				// break
				// println('module_search_paths:')
				// println(b.module_search_paths)
				verror('cannot import module "$mod" (not found)')
				break
			}
			v_files := b.v_files_from_dir(import_path)
			if v_files.len == 0 {
				// v.parsers[i].error_with_token_index('cannot import module "$mod" (no .v files in "$import_path")', v.parsers[i].import_table.get_import_tok_idx(mod))
				verror('cannot import module "$mod" (no .v files in "$import_path")')
			}
			// Add all imports referenced by these libs
			parsed_files := parser.parse_files(v_files, b.table, b.pref, b.global_scope)
			for file in parsed_files {
				if file.mod.name != mod {
					// v.parsers[pidx].error_with_token_index('bad module definition: ${v.parsers[pidx].file_path} imports module "$mod" but $file is defined as module `$p_mod`', 1
					verror('bad module definition: $ast_file.path imports module "$mod" but $file.path is defined as module `$file.mod.name`')
				}
			}
			b.parsed_files << parsed_files
			done_imports << mod
		}
	}
	b.resolve_deps()
	//
	if b.pref.print_v_files {
		for p in b.parsed_files {
			println(p.path)
		}
		exit(0)
	}
}

pub fn (mut b Builder) resolve_deps() {
	graph := b.import_graph()
	deps_resolved := graph.resolve()
	cycles := deps_resolved.display_cycles()
	if b.pref.is_verbose {
		eprintln('------ resolved dependencies graph: ------')
		eprintln(deps_resolved.display())
		eprintln('------------------------------------------')
	}
	if cycles.len > 1 {
		verror('error: import cycle detected between the following modules: \n' + cycles)
	}
	mut mods := []string{}
	for node in deps_resolved.nodes {
		mods << node.name
	}
	if b.pref.is_verbose {
		eprintln('------ imported modules: ------')
		eprintln(mods.str())
		eprintln('-------------------------------')
	}
	mut reordered_parsed_files := []ast.File{}
	for m in mods {
		for pf in b.parsed_files {
			if m == pf.mod.name {
				reordered_parsed_files << pf
				// eprintln('pf.mod.name: $pf.mod.name | pf.path: $pf.path')
			}
		}
	}
	b.table.modules = mods
	b.parsed_files = reordered_parsed_files
}

// graph of all imported modules
pub fn (b &Builder) import_graph() &depgraph.DepGraph {
	builtins := util.builtin_module_parts
	mut graph := depgraph.new_dep_graph()
	for p in b.parsed_files {
		mut deps := []string{}
		if p.mod.name !in builtins {
			deps << 'builtin'
			if b.pref.backend == .c {
				// TODO JavaScript backend doesn't handle os for now
				if b.pref.is_script && p.mod.name != 'os' {
					deps << 'os'
				}
			}
		}
		for m in p.imports {
			deps << m.mod
		}
		graph.add(p.mod.name, deps)
	}
	return graph
}

pub fn (b Builder) v_files_from_dir(dir string) []string {
	if !os.exists(dir) {
		if dir == 'compiler' && os.is_dir('vlib') {
			println('looks like you are trying to build V with an old command')
			println('use `v -o v cmd/v` instead of `v -o v compiler`')
		}
		verror("$dir doesn't exist")
	} else if !os.is_dir(dir) {
		verror("$dir isn't a directory!")
	}
	mut files := os.ls(dir) or {
		panic(err)
	}
	if b.pref.is_verbose {
		println('v_files_from_dir ("$dir")')
	}
	return b.pref.should_compile_filtered_files(dir, files)
}

pub fn (b Builder) log(s string) {
	if b.pref.is_verbose {
		println(s)
	}
}

pub fn (b Builder) info(s string) {
	if b.pref.is_verbose {
		println(s)
	}
}

[inline]
fn module_path(mod string) string {
	// submodule support
	return mod.replace('.', os.path_separator)
}

pub fn (b Builder) find_module_path(mod, fpath string) ?string {
	// support @VROOT/v.mod relative paths:
	mcache := vmod.get_cache()
	vmod_file_location := mcache.get_by_file(fpath)
	mod_path := module_path(mod)
	mut module_lookup_paths := []string{}
	if vmod_file_location.vmod_file.len != 0 &&
		vmod_file_location.vmod_folder !in b.module_search_paths {
		module_lookup_paths << vmod_file_location.vmod_folder
	}
	module_lookup_paths << b.module_search_paths
	for search_path in module_lookup_paths {
		try_path := os.join_path(search_path, mod_path)
		if b.pref.is_verbose {
			println('  >> trying to find $mod in $try_path ..')
		}
		if os.is_dir(try_path) {
			if b.pref.is_verbose {
				println('  << found $try_path .')
			}
			return try_path
		}
	}
	smodule_lookup_paths := module_lookup_paths.join(', ')
	return error('module "$mod" not found in:\n$smodule_lookup_paths')
}

fn (b &Builder) print_warnings_and_errors() {
	if b.pref.output_mode == .silent {
		if b.checker.nr_errors > 0 {
			exit(1)
		}
		return
	}
	if b.pref.is_verbose && b.checker.nr_warnings > 1 {
		println('$b.checker.nr_warnings warnings')
	}
	if b.checker.nr_warnings > 0 && !b.pref.skip_warnings {
		for i, err in b.checker.warnings {
			kind := if b.pref.is_verbose { '$err.reporter warning #$b.checker.nr_warnings:' } else { 'warning:' }
			ferror := util.formatted_error(kind, err.message, err.file_path, err.pos)
			eprintln(ferror)
			if err.details.len > 0 {
				eprintln('details: $err.details')
			}
			// eprintln('')
			if i > b.max_nr_errors {
				return
			}
		}
	}
	//
	if b.pref.is_verbose && b.checker.nr_errors > 1 {
		println('$b.checker.nr_errors errors')
	}
	if b.checker.nr_errors > 0 {
		for i, err in b.checker.errors {
			kind := if b.pref.is_verbose { '$err.reporter error #$b.checker.nr_errors:' } else { 'error:' }
			ferror := util.formatted_error(kind, err.message, err.file_path, err.pos)
			eprintln(ferror)
			if err.details.len > 0 {
				eprintln('details: $err.details')
			}
			// eprintln('')
			if i > b.max_nr_errors {
				return
			}
		}
		exit(1)
	}
	if b.table.redefined_fns.len > 0 {
		for fn_name in b.table.redefined_fns {
			eprintln('redefinition of function `$fn_name`')
			// eprintln('previous declaration at')
			// Find where this function was already declared
			for file in b.parsed_files {
				for stmt in file.stmts {
					if stmt is ast.FnDecl {
						if stmt.name == fn_name {
							fline := stmt.pos.line_nr
							println('$file.path:$fline:')
						}
					}
				}
			}
			exit(1)
		}
	}
}

fn verror(s string) {
	util.verror('builder error', s)
}

pub fn (mut b Builder) timing_message(msg string) {
	if b.pref.show_timings {
		println(msg)
	} else {
		b.info(msg)
	}
}
