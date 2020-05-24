module js

import strings
import v.ast
import v.table
import v.pref
import v.util
import v.depgraph

const (
	// https://ecma-international.org/ecma-262/#sec-reserved-words
	js_reserved = ['await', 'break', 'case', 'catch', 'class', 'const', 'continue', 'debugger',
		'default', 'delete', 'do', 'else', 'enum', 'export', 'extends', 'finally', 'for', 'function',
		'if', 'implements', 'import', 'in', 'instanceof', 'interface', 'let', 'new', 'package', 'private',
		'protected', 'public', 'return', 'static', 'super', 'switch', 'this', 'throw', 'try', 'typeof',
		'var', 'void', 'while', 'with', 'yield']
	tabs = ['', '\t', '\t\t', '\t\t\t', '\t\t\t\t', '\t\t\t\t\t', '\t\t\t\t\t\t', '\t\t\t\t\t\t\t', '\t\t\t\t\t\t\t\t']
	builtin_globals = ['println', 'print']
	type_values = {

	}
)

struct JsGen {
	table             &table.Table
	definitions       strings.Builder
	pref              &pref.Preferences
mut:
	out               strings.Builder
	namespaces        map[string]strings.Builder
	namespaces_pub    map[string][]string
	namespace_imports map[string]map[string]string
	namespace         string
	doc               &JsDoc
	enable_doc        bool
	constants         strings.Builder // all global V constants
	file              ast.File
	tmp_count         int
	inside_ternary    bool
	inside_loop       bool
	is_test           bool
	indents           map[string]int // indentations mapped to namespaces
	stmt_start_pos    int
	defer_stmts       []ast.DeferStmt
	fn_decl           &ast.FnDecl // pointer to the FnDecl we are currently inside otherwise 0
	str_types         []string // types that need automatic str() generation
	method_fn_decls   map[string][]ast.Stmt
	empty_line        bool
}

pub fn gen(files []ast.File, table &table.Table, pref &pref.Preferences) string {
	mut g := &JsGen{
		out: strings.new_builder(100)
		definitions: strings.new_builder(100)
		constants: strings.new_builder(100)
		table: table
		pref: pref
		fn_decl: 0
		empty_line: true
		doc: 0
		enable_doc: true
	}
	g.doc = new_jsdoc(g)
	// TODO: Add '[-no]-jsdoc' flag
	if pref.is_prod {
		g.enable_doc = false
	}
	g.init()

	mut graph := depgraph.new_dep_graph()

	// Get class methods
	for file in files {
		g.file = file
		g.enter_namespace(g.file.mod.name)
		g.is_test = g.file.path.ends_with('_test.v')
		g.find_class_methods(file.stmts)
		g.escape_namespace()
	}

	for file in files {
		g.file = file
		g.enter_namespace(g.file.mod.name)
		g.is_test = g.file.path.ends_with('_test.v')

		// store imports
		mut imports := []string{}
		for imp in g.file.imports {
			imports << imp.mod
		}
		graph.add(g.file.mod.name, imports)

		g.stmts(file.stmts)
		// store the current namespace
		g.escape_namespace()
	}

	// resolve imports
	deps_resolved := graph.resolve()

	g.finish()
	mut out := g.hashes() + g.definitions.str() + g.constants.str()
	for node in deps_resolved.nodes {
		out += g.doc.gen_namespace(node.name)
		out += 'const $node.name = (function ('
		imports := g.namespace_imports[node.name]
		for i, key in imports.keys() {
			if i > 0 { out += ', ' }
			out += imports[key]
		}
		out += ') {\n\t'
		// private scope
		out += g.namespaces[node.name].str().trim_space()
		// public scope
		out += '\n\n\t/* module exports */'
		out += '\n\treturn {'
		for pub_var in g.namespaces_pub[node.name] {
			out += '\n\t\t$pub_var,'
		}
		if g.namespaces_pub[node.name].len > 0 { out += '\n\t' }
		out += '};'
		out += '\n})('
		for i, key in imports.keys() {
			if i > 0 { out += ', ' }
			out += key
		}
		out += ');\n\n'
	}
	return out
}

pub fn (mut g JsGen) enter_namespace(n string) {
	g.namespace = n
	if g.namespaces[g.namespace].len == 0 {
		// create a new namespace
		g.out = strings.new_builder(100)
		g.indents[g.namespace] = 0
	} else {
		g.out = g.namespaces[g.namespace]
	}
}

pub fn (mut g JsGen) escape_namespace() {
	g.namespaces[g.namespace] = g.out
	g.namespace = ''
}

pub fn (mut g JsGen) push_pub_var(s string) {
	mut arr := g.namespaces_pub[g.namespace]
	arr << g.js_name(s)
	g.namespaces_pub[g.namespace] = arr
}

pub fn (mut g JsGen) find_class_methods(stmts []ast.Stmt) {
	for stmt in stmts {
		match stmt {
			ast.FnDecl {
				if it.is_method {
					// Found struct method, store it to be generated along with the class.
					class_name := g.table.get_type_name(it.receiver.typ)
					// Workaround until `map[key] << val` works.
					mut arr := g.method_fn_decls[class_name]
					arr << stmt
					g.method_fn_decls[class_name] = arr
				}
			}
			else {}
		}
	}
}

pub fn (mut g JsGen) init() {
	g.definitions.writeln('// Generated by the V compiler\n')
	g.definitions.writeln('"use strict";')
	g.definitions.writeln('')
}

pub fn (mut g JsGen) finish() {
	if g.constants.len > 0 {
		constants := g.constants.str()
		g.constants = strings.new_builder(100)
		g.constants.writeln('const _CONSTS = Object.freeze({')
		g.constants.write(constants)
		g.constants.writeln('});')
		g.constants.writeln('')
	}
}

pub fn (g JsGen) hashes() string {
	mut res := '// V_COMMIT_HASH ${util.vhash()}\n'
	res += '// V_CURRENT_COMMIT_HASH ${util.githash(g.pref.building_v)}\n'
	return res
}

// V type to JS type
pub fn (mut g JsGen) typ(t table.Type) string {
	sym := g.table.get_type_symbol(t)
	mut styp := sym.name
	if styp.starts_with('JS.') {
		styp = styp[3..]
	}
	// 'multi_return_int_int' => '[number, number]'
	if styp.starts_with('multi_return_') {
		tokens := styp.replace('multi_return_', '').split('_')
		return '[' + tokens.map(g.to_js_typ(it)).join(', ') + ']'
	}
	// 'anon_fn_7_7_1' => '(a number, b number) => void'
	if styp.starts_with('anon_') {
		info := sym.info as table.FnType
		mut res := '('
		for i, arg in info.func.args {
			res += '$arg.name: ${g.typ(arg.typ)}'
			if i < info.func.args.len - 1 { res += ', ' }
		}
		return res + ') => ' + g.typ(info.func.return_type)
	}
	// Struct instance => ns["class"]["prototype"]
	if sym.kind == .struct_ && get_ns(styp).len > 0 {
		return g.to_js_typ(g.get_alias(styp)) + '["prototype"]'
	}
	return g.to_js_typ(styp)
}

fn (mut g JsGen) to_js_typ(typ string) string {
	mut styp := ''
	match typ {
		'int' {
			styp = 'number'
		}
		'bool' {
			styp = 'boolean'
		}
		'voidptr' {
			styp = 'Object'
		}
		'byteptr' {
			styp = 'string'
		}
		'charptr' {
			styp = 'string'
		}
		else {
			if typ.starts_with('array_') {
				styp = g.to_js_typ(typ.replace('array_', '')) + '[]'
			} else if typ.starts_with('map_') {
				tokens := typ.split('_')
				styp = 'Map<${g.to_js_typ(tokens[1])}, ${g.to_js_typ(tokens[2])}>'
			} else {
				styp = typ
			}
		}
	}
	// ns.export => ns["export"]
	for i, v in styp.split('.') {
		if i == 0 {
			styp = v
			continue
		}
		styp += '["$v"]'
	}
	return styp
}

fn (mut g JsGen) to_js_typ_val(typ string) string {
	mut styp := ''
	match typ {
		'number' {
			styp = '0'
		}
		'boolean' {
			styp = 'false'
		}
		'Object' {
			styp = '{}'
		}
		'string' {
			styp = '""'
		}
		else {
			if typ.starts_with('Map') {
				styp = 'new Map()'
			} else if typ.ends_with('[]') {
				styp = '[]'
			} else {
				styp = '{}'
			}
		}
	}
	// ns.export => ns["export"]
	for i, v in styp.split('.') {
		if i == 0 {
			styp = v
			continue
		}
		styp += '["$v"]'
	}
	return styp
}

pub fn (g &JsGen) save() {}

pub fn (mut g JsGen) gen_indent() {
	if g.indents[g.namespace] > 0 && g.empty_line {
		g.out.write(tabs[g.indents[g.namespace]])
	}
	g.empty_line = false
}

pub fn (mut g JsGen) inc_indent() {
	g.indents[g.namespace]++
}

pub fn (mut g JsGen) dec_indent() {
	g.indents[g.namespace]--
}

pub fn (mut g JsGen) write(s string) {
	g.gen_indent()
	g.out.write(s)
}

pub fn (mut g JsGen) writeln(s string) {
	g.gen_indent()
	g.out.writeln(s)
	g.empty_line = true
}

pub fn (mut g JsGen) new_tmp_var() string {
	g.tmp_count++
	return '_tmp$g.tmp_count'
}

// 'mod1.mod2.fn' => 'mod1.mod2'
// 'fn' => ''
[inline]
fn get_ns(s string) string {
	parts := s.split('.')
	mut res := ''
	for i, p in parts {
		if i == parts.len - 1 { break } // Last part (fn/struct/var name): skip
		res += p
		if i < parts.len - 2 { res += '.' } // Avoid trailing dot
	}
	return res
}

fn (mut g JsGen) get_alias(name string) string {
	// TODO: This is a hack; find a better way to do this
	split := name.split('.')
	if split.len > 1 {
		imports := g.namespace_imports[g.namespace]
		alias := imports[split[0]]

		if alias != '' {
			return alias + '.' + split[1..].join('.')
		}
	}
	return name // No dot == no alias
}

fn (mut g JsGen) js_name(name_ string) string {
	ns := get_ns(name_)
	mut name := if ns == g.namespace { name_.split('.').last() } else { g.get_alias(name_) }
	mut parts := name.split('.')
	for i, p in parts {
		if p in js_reserved { parts[i] = 'v_$p' }
	}
	return parts.join('.')
}

fn (mut g JsGen) stmts(stmts []ast.Stmt) {
	g.inc_indent()
	for stmt in stmts {
		g.stmt(stmt)
	}
	g.dec_indent()
}

fn (mut g JsGen) stmt(node ast.Stmt) {
	g.stmt_start_pos = g.out.len

	match node {
		ast.AssertStmt {
			g.gen_assert_stmt(it)
		}
		ast.AssignStmt {
			g.gen_assign_stmt(it)
		}
		ast.Attr {
			g.gen_attr(it)
		}
		ast.Block {
			g.gen_block(it)
			g.writeln('')
		}
		ast.BranchStmt {
			g.gen_branch_stmt(it)
		}
		ast.Comment {
			// Skip: don't generate comments
		}
		ast.CompIf {
			// skip: JS has no compile time if
		}
		ast.ConstDecl {
			g.gen_const_decl(it)
		}
		ast.DeferStmt {
			g.defer_stmts << *it
		}
		ast.EnumDecl {
			g.gen_enum_decl(it)
			g.writeln('')
		}
		ast.ExprStmt {
			g.gen_expr_stmt(it)
		}
		ast.FnDecl {
			g.fn_decl = it
			g.gen_fn_decl(it)
			g.writeln('')
		}
		ast.ForCStmt {
			g.gen_for_c_stmt(it)
			g.writeln('')
		}
		ast.ForInStmt {
			g.gen_for_in_stmt(it)
			g.writeln('')
		}
		ast.ForStmt {
			g.gen_for_stmt(it)
			g.writeln('')
		}
		ast.GlobalDecl {
			// TODO
		}
		ast.GoStmt {
			g.gen_go_stmt(it)
			g.writeln('')
		}
		ast.GotoLabel {
			g.writeln('${g.js_name(it.name)}:')
		}
		ast.GotoStmt {
			// skip: JS has no goto
		}
		ast.HashStmt {
			// skip: nothing with # in JS
		}
		ast.Import {
			g.gen_import_stmt(it)
		}
		ast.InterfaceDecl {
			// TODO skip: interfaces not implemented yet
		}
		ast.Module {
			// skip: namespacing implemented externally
		}
		ast.Return {
			if g.defer_stmts.len > 0 {
				g.gen_defer_stmts()
			}
			g.gen_return_stmt(it)
		}
		ast.StructDecl {
			g.gen_struct_decl(it)
		}
		ast.TypeDecl {
			// skip JS has no typedecl
		}
		ast.UnsafeStmt {
			g.stmts(it.stmts)
		}
		/*
		else {
			verror('jsgen.stmt(): bad node ${typeof(node)}')
		}
		*/
	}
}

fn (mut g JsGen) expr(node ast.Expr) {
	match node {
		ast.AnonFn {
			g.gen_fn_decl(it.decl)
		}
		ast.ArrayInit {
			g.gen_array_init_expr(it)
		}
		ast.AsCast {
			// skip: JS has no types, so no need to cast
			// TODO: Is jsdoc needed here for TS support?
		}
		ast.AssignExpr {
			g.gen_assign_expr(it)
		}
		ast.Assoc {
			// TODO
		}
		ast.BoolLiteral {
			if it.val == true {
				g.write('true')
			} else {
				g.write('false')
			}
		}
		ast.CallExpr {
			g.gen_call_expr(it)
		}
		ast.CastExpr {
			// skip: JS has no types, so no need to cast
			// TODO: Check if jsdoc is needed for TS support
		}
		ast.CharLiteral {
			g.write("'$it.val'")
		}
		ast.ConcatExpr {
			// TODO
		}
		ast.EnumVal {
			styp := g.typ(it.typ)
			g.write('${styp}.${it.val}')
		}
		ast.FloatLiteral {
			g.write(it.val)
		}
		ast.Ident {
			g.gen_ident(it)
		}
		ast.IfExpr {
			g.gen_if_expr(it)
		}
		ast.IfGuardExpr {
			// TODO no optionals yet
		}
		ast.IndexExpr {
			g.gen_index_expr(it)
		}
		ast.InfixExpr {
			g.gen_infix_expr(it)
		}
		ast.IntegerLiteral {
			g.write(it.val)
		}
		ast.MapInit {
			g.gen_map_init_expr(it)
		}
		ast.MatchExpr {
			// TODO
		}
		ast.None {
			// TODO
		}
		ast.OrExpr {
			// TODO
		}
		ast.ParExpr {
			// TODO
		}
		ast.PostfixExpr {
			g.expr(it.expr)
			g.write(it.op.str())
		}
		ast.PrefixExpr {
			// TODO
		}
		ast.RangeExpr {
			// Only used in IndexExpr, requires index type info
		}
		ast.SelectorExpr {
			g.gen_selector_expr(it)
		}
		ast.SizeOf {
			// TODO
		}
		ast.StringInterLiteral {
			g.gen_string_inter_literal(it)
		}
		ast.StringLiteral {
			g.write('"$it.val"')
		}
		ast.StructInit {
			// `user := User{name: 'Bob'}`
			g.gen_struct_init(it)
		}
		ast.Type {
			// skip: JS has no types
			// TODO maybe?
		}
		ast.TypeOf {
			g.gen_typeof_expr(it)
			// TODO: Should this print the V type or the JS type?
		}
		/*
		else {
			println(term.red('jsgen.expr(): unhandled node "${typeof(node)}"'))
		}
		*/
	}
}


// TODO
fn (mut g JsGen) gen_assert_stmt(a ast.AssertStmt) {
	g.writeln('// assert')
	g.write('if( ')
	g.expr(a.expr)
	g.write(' ) {')
	s_assertion := a.expr.str().replace('"', "\'")
	mut mod_path := g.file.path
	if g.is_test {
		g.writeln('	g_test_oks++;')
		g.writeln('	cb_assertion_ok("${mod_path}", ${a.pos.line_nr+1}, "assert ${s_assertion}", "${g.fn_decl.name}()" );')
		g.writeln('} else {')
		g.writeln('	g_test_fails++;')
		g.writeln('	cb_assertion_failed("${mod_path}", ${a.pos.line_nr+1}, "assert ${s_assertion}", "${g.fn_decl.name}()" );')
		g.writeln('	exit(1);')
		g.writeln('}')
		return
	}
	g.writeln('} else {')
	g.writeln('	eprintln("${mod_path}:${a.pos.line_nr+1}: FAIL: fn ${g.fn_decl.name}(): assert $s_assertion");')
	g.writeln('	exit(1);')
	g.writeln('}')
}

fn (mut g JsGen) gen_assign_stmt(it ast.AssignStmt) {
	if it.left.len > it.right.len {
		// multi return
		jsdoc := strings.new_builder(50)
		jsdoc.write('[')
		stmt := strings.new_builder(50)
		stmt.write('const [')
		for i, ident in it.left {
			ident_var_info := ident.var_info()
			styp := g.typ(ident_var_info.typ)
			jsdoc.write(styp)

			stmt.write(g.js_name(ident.name))

			if i < it.left.len - 1 {
				jsdoc.write(', ')
				stmt.write(', ')
			}
		}
		jsdoc.write(']')
		stmt.write('] = ')
		g.writeln(g.doc.gen_typ(jsdoc.str(), ''))
		g.write(stmt.str())
		g.expr(it.right[0])
		g.writeln(';')
	} else {
		// `a := 1` | `a,b := 1,2`
		for i, ident in it.left {
			val := it.right[i]
			ident_var_info := ident.var_info()
			mut styp := g.typ(ident_var_info.typ)

			if val is ast.EnumVal {
				// we want the type of the enum value not the enum
				styp = 'number'
			} else if val is ast.StructInit {
				// no need to print jsdoc for structs
				styp = ''
			}

			if !g.inside_loop && styp.len > 0 {
				g.writeln(g.doc.gen_typ(styp, ident.name))
			}

			if g.inside_loop || ident.is_mut {
				g.write('let ')
			} else {
				g.write('const ')
			}

			g.write('${g.js_name(ident.name)} = ')
			g.expr(val)

			if g.inside_loop {
				g.write('; ')
			} else {
				g.writeln(';')
			}
		}
	}
}

fn (mut g JsGen) gen_attr(it ast.Attr) {
	g.writeln('/* [$it.name] */')
}

fn (mut g JsGen) gen_block(it ast.Block) {
	g.writeln('{')
	g.stmts(it.stmts)
	g.writeln('}')
}

fn (mut g JsGen) gen_branch_stmt(it ast.BranchStmt) {
	// continue or break
	g.write(it.tok.kind.str())
	g.writeln(';')
}

fn (mut g JsGen) gen_const_decl(it ast.ConstDecl) {
	// old_indent := g.indents[g.namespace]
	for i, field in it.fields {
		// TODO hack. Cut the generated value and paste it into definitions.
		pos := g.out.len
		g.expr(field.expr)
		val := g.out.after(pos)
		g.out.go_back(val.len)
		if g.enable_doc {
			typ := g.typ(field.typ)
			g.constants.write('\t')
			g.constants.writeln(g.doc.gen_typ(typ, field.name))
		}
		g.constants.write('\t')
		g.constants.write('${g.js_name(field.name)}: $val')
		if i < it.fields.len - 1 {
			g.constants.writeln(',')
		}
	}
	g.constants.writeln('')
}

fn (mut g JsGen) gen_defer_stmts() {
	g.writeln('(function defer() {')
	for defer_stmt in g.defer_stmts {
		g.stmts(defer_stmt.stmts)
	}
	g.defer_stmts = []
	g.writeln('})();')
}

fn (mut g JsGen) gen_enum_decl(it ast.EnumDecl) {
	g.writeln('const ${g.js_name(it.name)} = Object.freeze({')
	g.inc_indent()
	for i, field in it.fields {
		g.write('$field.name: ')
		if field.has_expr {
			pos := g.out.len
			g.expr(field.expr)
			expr_str := g.out.after(pos)
			g.out.go_back(expr_str.len)
			g.write('$expr_str')
		} else {
			g.write('$i')
		}
		g.writeln(',')
	}
	g.dec_indent()
	g.writeln('});')
	if it.is_pub {
		g.push_pub_var(it.name)
	}
}

fn (mut g JsGen) gen_expr_stmt(it ast.ExprStmt) {
	g.expr(it.expr)
	expr := it.expr
	if expr is ast.IfExpr { } // no ; after an if expression
	else if !g.inside_ternary { g.writeln(';') }
}

fn (mut g JsGen) gen_fn_decl(it ast.FnDecl) {
	if it.is_method {
		// Struct methods are handled by class generation code.
		return
	}
	if it.no_body {
		return
	}
	g.gen_method_decl(it)
}

fn fn_has_go(it ast.FnDecl) bool {
	mut has_go := false
	for stmt in it.stmts {
		if stmt is ast.GoStmt { has_go = true }
	}
	return has_go
}

fn (mut g JsGen) gen_method_decl(it ast.FnDecl) {
	g.fn_decl = &it
	has_go := fn_has_go(it)
	is_main := it.name == 'main'
	if is_main {
		// there is no concept of main in JS but we do have iife
		g.writeln('/* program entry point */')
		g.write('(')
		if has_go {
			g.write('async ')
		}
		g.write('function(')
	} else if it.is_anon {
		g.write('function (')
	} else {
		mut name := g.js_name(it.name)
		c := name[0]
		if c in [`+`, `-`, `*`, `/`] {
			name = util.replace_op(name)
		}

		// type_name := g.typ(it.return_type)

		// generate jsdoc for the function
		g.writeln(g.doc.gen_fn(it))

		if has_go {
			g.write('async ')
		}
		if !it.is_method {
			g.write('function ')
		}
		g.write('${name}(')

		if it.is_pub && !it.is_method {
			g.push_pub_var(name)
		}
	}

	mut args := it.args
	if it.is_method {
		args = args[1..]
	}
	g.fn_args(args, it.is_variadic)
	g.writeln(') {')

	if it.is_method {
		g.inc_indent()
		g.writeln('const ${it.args[0].name} = this;')
		g.dec_indent()
	}

	g.stmts(it.stmts)
	g.write('}')
	if is_main {
		g.write(')();')
	}
	if !it.is_anon && !it.is_method {
		g.writeln('')
	}

	g.fn_decl = 0
}

fn (mut g JsGen) fn_args(args []table.Arg, is_variadic bool) {
	// no_names := args.len > 0 && args[0].name == 'arg_1'
	for i, arg in args {
		name := g.js_name(arg.name)
		is_varg := i == args.len - 1 && is_variadic
		if is_varg {
			g.write('...$name')
		} else {
			g.write(name)
		}
		// if its not the last argument
		if i < args.len - 1 {
			g.write(', ')
		}
	}
}

fn (mut g JsGen) gen_for_c_stmt(it ast.ForCStmt) {
	g.inside_loop = true
	g.write('for (')
	if it.has_init {
		g.stmt(it.init)
	} else {
		g.write('; ')
	}
	if it.has_cond {
		g.expr(it.cond)
	}
	g.write('; ')
	if it.has_inc {
		g.expr(it.inc)
	}
	g.writeln(') {')
	g.stmts(it.stmts)
	g.writeln('}')
	g.inside_loop = false
}

fn (mut g JsGen) gen_for_in_stmt(it ast.ForInStmt) {
	if it.is_range {
		// `for x in 1..10 {`
		i := it.val_var
		g.inside_loop = true
		g.write('for (let $i = ')
		g.expr(it.cond)
		g.write('; $i < ')
		g.expr(it.high)
		g.writeln('; ++$i) {')
		g.inside_loop = false
		g.stmts(it.stmts)
		g.writeln('}')
	} else if it.kind == .array || it.cond_type.flag_is(.variadic) {
		// `for num in nums {`
		i := if it.key_var == '' { g.new_tmp_var() } else { it.key_var }
		// styp := g.typ(it.val_type)
		g.inside_loop = true
		g.write('for (let $i = 0; $i < ')
		g.expr(it.cond)
		g.writeln('.length; ++$i) {')
		g.inside_loop = false
		g.write('\tlet $it.val_var = ')
		g.expr(it.cond)
		g.writeln('[$i];')
		g.stmts(it.stmts)
		g.writeln('}')
	} else if it.kind == .map {
		// `for key, val in map[string]int {`
		// key_styp := g.typ(it.key_type)
		// val_styp := g.typ(it.val_type)
		key := if it.key_var == '' { g.new_tmp_var() } else { it.key_var }
		g.write('for (let [$key, $it.val_var] of ')
		g.expr(it.cond)
		g.writeln(') {')
		g.stmts(it.stmts)
		g.writeln('}')
	} else if it.kind == .string {
		// `for x in 'hello' {`
		i := if it.key_var == '' { g.new_tmp_var() } else { it.key_var }
		g.inside_loop = true
		g.write('for (let $i = 0; $i < ')
		g.expr(it.cond)
		g.writeln('.length; ++$i) {')
		g.inside_loop = false
		g.write('\tlet $it.val_var = ')
		g.expr(it.cond)
		g.writeln('[$i];')
		g.stmts(it.stmts)
		g.writeln('}')
	}
}

fn (mut g JsGen) gen_for_stmt(it ast.ForStmt) {
	g.write('while (')
	if it.is_inf {
		g.write('true')
	} else {
		g.expr(it.cond)
	}
	g.writeln(') {')
	g.stmts(it.stmts)
	g.writeln('}')
}

fn (mut g JsGen) gen_go_stmt(node ast.GoStmt) {
	// x := node.call_expr as ast.CallEpxr // TODO
	match node.call_expr {
		ast.CallExpr {
			mut name := it.name
			if it.is_method {
				receiver_sym := g.table.get_type_symbol(it.receiver_type)
				name = receiver_sym.name + '.' + name
			}
			g.writeln('await new Promise(function(resolve){')
			g.inc_indent()
			g.write('${name}(')
			for i, arg in it.args {
				g.expr(arg.expr)
				if i < it.args.len - 1 {
					g.write(', ')
				}
			}
			g.writeln(');')
			g.writeln('resolve();')
			g.dec_indent()
			g.writeln('});')
		}
		else {}
	}
}

fn (mut g JsGen) gen_import_stmt(it ast.Import) {
	mut imports := g.namespace_imports[g.namespace]
	imports[it.mod] = it.alias
	g.namespace_imports[g.namespace] = imports
}

fn (mut g JsGen) gen_return_stmt(it ast.Return) {
	if it.exprs.len == 0 {
		// Returns nothing
		g.write('return;')
		return
	}

	g.write('return ')
	if it.exprs.len == 1 {
		g.expr(it.exprs[0])
	} else {
		// Multi return
		g.write('[')
		for i, expr in it.exprs {
			g.expr(expr)
			if i < it.exprs.len - 1 {
				g.write(', ')
			}
		}
		g.write(']')
	}
	g.writeln(';')
}

fn (mut g JsGen) gen_struct_decl(node ast.StructDecl) {
	g.writeln(g.doc.gen_fac_fn(node.fields))
	g.write('function ${g.js_name(node.name)}({ ')
	for i, field in node.fields {
		g.write('$field.name = ')
		if field.has_default_expr {
			g.expr(field.default_expr)
		} else {
			g.write('${g.to_js_typ_val(g.typ(field.typ))}')
		}
		if i < node.fields.len - 1 { g.write(', ') }
	}
	g.writeln(' }) {')
	g.inc_indent()
	for field in node.fields {
		g.writeln('this.$field.name = $field.name')
	}
	g.dec_indent()
	g.writeln('};')

	g.writeln('${g.js_name(node.name)}.prototype = {')
	g.inc_indent()

	fns := g.method_fn_decls[node.name]

	for i, field in node.fields {
		g.writeln(g.doc.gen_typ(g.typ(field.typ), field.name))
		g.write('$field.name: ${g.to_js_typ_val(g.typ(field.typ))}')
		if i < node.fields.len - 1 || fns.len > 0 { g.writeln(',') } else { g.writeln('') }
	}

	for i, cfn in fns {
		// TODO: Move cast to the entire array whenever it's possible
		it := cfn as ast.FnDecl
		g.gen_method_decl(it)
		if i < fns.len - 1 { g.writeln(',') } else { g.writeln('') }
	}
	g.dec_indent()
	g.writeln('};\n')
	if node.is_pub {
		g.push_pub_var(node.name)
	}
}

fn (mut g JsGen) gen_array_init_expr(it ast.ArrayInit) {
	type_sym := g.table.get_type_symbol(it.typ)
	if type_sym.kind != .array_fixed {
		g.write('[')
		for i, expr in it.exprs {
			g.expr(expr)
			if i < it.exprs.len - 1 {
				g.write(', ')
			}
		}
		g.write(']')
	} else {}
}

fn (mut g JsGen) gen_assign_expr(it ast.AssignExpr) {
	g.expr(it.left)
	g.write(' $it.op ')
	g.expr(it.val)
}

fn (mut g JsGen) gen_call_expr(it ast.CallExpr) {
	mut name := ''
	if it.name.starts_with('JS.') {
		name = it.name[3..]
	} else {
		name = g.js_name(it.name)
	}
	g.expr(it.left)
	if it.is_method {
		// example: foo.bar.baz()
		g.write('.')
	} else {
		if name in builtin_globals {
			g.write('builtin.')
		}
	}
	g.write('${g.js_name(name)}(')
	for i, arg in it.args {
		g.expr(arg.expr)
		if i != it.args.len - 1 {
			g.write(', ')
		}
	}
	g.write(')')
}

fn (mut g JsGen) gen_ident(node ast.Ident) {
	if node.kind == .constant {
		// TODO: Handle const namespacing: only consts in the main module are handled rn
		g.write('_CONSTS.')
	}

	name := g.js_name(node.name)
	// TODO `is`
	// TODO handle optionals
	g.write(name)
}

fn (mut g JsGen) gen_if_expr(node ast.IfExpr) {
	type_sym := g.table.get_type_symbol(node.typ)

	// one line ?:
	if node.is_expr && node.branches.len >= 2 && node.has_else && type_sym.kind != .void {
		// `x := if a > b {  } else if { } else { }`
		g.write('(')
		g.inside_ternary = true
		for i, branch in node.branches {
			if i > 0 {
				g.write(' : ')
			}
			if i < node.branches.len - 1 || !node.has_else {
				g.expr(branch.cond)
				g.write(' ? ')
			}
			g.stmts(branch.stmts)
		}
		g.inside_ternary = false
		g.write(')')
	} else {
		// mut is_guard = false
		for i, branch in node.branches {
			if i == 0 {
				match branch.cond {
					ast.IfGuardExpr {
						// TODO optionals
					}
					else {
						g.write('if (')
						g.expr(branch.cond)
						g.writeln(') {')
					}
				}
			} else if i < node.branches.len - 1 || !node.has_else {
				g.write('} else if (')
				g.expr(branch.cond)
				g.writeln(') {')
			} else if i == node.branches.len - 1 && node.has_else {
				/* if is_guard {
					//g.writeln('} if (!$guard_ok) { /* else */')
				} else { */
				g.writeln('} else {')
				// }
			}
			g.stmts(branch.stmts)
		}
		/* if is_guard {
			g.write('}')
		} */
		g.writeln('}')
		g.writeln('')
	}
}

fn (mut g JsGen) gen_index_expr(it ast.IndexExpr) {
	// TODO: Handle splice setting if it's implemented
	if it.index is ast.RangeExpr {
		range := it.index as ast.RangeExpr
		g.expr(it.left)
		g.write('.slice(')
		if range.has_low {
			g.expr(range.low)
		} else {
			g.write('0')
		}
		g.write(', ')
		if range.has_high {
			g.expr(range.high)
		} else {
			g.expr(it.left)
			g.write('.length')
		}
		g.write(')')
	} else {
		// TODO Does this work in all cases?
		g.expr(it.left)
		g.write('[')
		g.expr(it.index)
		g.write(']')
	}
}

fn (mut g JsGen) gen_infix_expr(it ast.InfixExpr) {
	g.expr(it.left)

	mut op := it.op.str()
	// in js == is non-strict & === is strict, always do strict
	if op == '==' { op = '===' }
	else if op == '!=' { op = '!==' }

	g.write(' $op ')
	g.expr(it.right)
}


fn (mut g JsGen) gen_map_init_expr(it ast.MapInit) {
	// key_typ_sym := g.table.get_type_symbol(it.key_type)
	// value_typ_sym := g.table.get_type_symbol(it.value_type)
	// key_typ_str := key_typ_sym.name.replace('.', '__')
	// value_typ_str := value_typ_sym.name.replace('.', '__')
	if it.vals.len > 0 {
		g.writeln('new Map([')
		g.inc_indent()
		for i, key in it.keys {
			val := it.vals[i]
			g.write('[')
			g.expr(key)
			g.write(', ')
			g.expr(val)
			g.write(']')
			if i < it.keys.len - 1 {
				g.write(',')
			}
			g.writeln('')
		}
		g.dec_indent()
		g.write('])')
	} else {
		g.write('new Map()')
	}
}

fn (mut g JsGen) gen_selector_expr(it ast.SelectorExpr) {
	g.expr(it.expr)
	g.write('.$it.field_name')
}

fn (mut g JsGen) gen_string_inter_literal(it ast.StringInterLiteral) {
	// TODO Implement `tos3`
	g.write('tos3(`')
	for i, val in it.vals {
		escaped_val := val.replace_each(['`', '\`', '\r\n', '\n'])
		g.write(escaped_val)
		if i >= it.exprs.len {
			continue
		}
		expr := it.exprs[i]
		sfmt := it.expr_fmts[i]
		g.write('\${')
		if sfmt.len > 0 {
			fspec := sfmt[sfmt.len - 1]
			if fspec == `s` && it.expr_types[i] == table.string_type {
				g.expr(expr)
				g.write('.str')
			} else {
				g.expr(expr)
			}
		} else if it.expr_types[i] == table.string_type {
			// `name.str`
			g.expr(expr)
			g.write('.str')
		} else if it.expr_types[i] == table.bool_type {
			// `expr ? "true" : "false"`
			g.expr(expr)
			g.write(' ? "true" : "false"')
		} else {
			sym := g.table.get_type_symbol(it.expr_types[i])

			match sym.kind {
				.struct_ {
					g.expr(expr)
					if sym.has_method('str') {
						g.write('.str()')
					}
				}
				else {
					g.expr(expr)
				}
			}
		}
		g.write('}')
	}
	g.write('`)')
}

fn (mut g JsGen) gen_struct_init(it ast.StructInit) {
	type_sym := g.table.get_type_symbol(it.typ)
	name := type_sym.name
	if it.fields.len == 0 {
		g.write('new ${g.js_name(name)}({})')
	} else {
		g.writeln('new ${g.js_name(name)}({')
		g.inc_indent()
		for i, field in it.fields {
			g.write('$field.name: ')
			g.expr(field.expr)
			if i < it.fields.len - 1 {
				g.write(',')
			}
			g.writeln('')
		}
		g.dec_indent()
		g.write('})')
	}
}

fn (mut g JsGen) gen_typeof_expr(it ast.TypeOf) {
	// TODO: Should this print the V type or the JS type?
	// If V type: Uncomment below
	/*
	sym := g.table.get_type_symbol(it.expr_type)
	if sym.kind == .sum_type {
		// TODO
	} else if sym.kind == .array_fixed {
		fixed_info := sym.info as table.ArrayFixed
		typ_name := g.table.get_type_name(fixed_info.elem_type)
		g.write('"[$fixed_info.size]${typ_name}"')
	} else if sym.kind == .function {
		info := sym.info as table.FnType
		fn_info := info.func
		mut repr := 'fn ('
		for i, arg in fn_info.args {
			if i > 0 {
				repr += ', '
			}
			repr += g.table.get_type_name(arg.typ)
		}
		repr += ')'
		if fn_info.return_type != table.void_type {
			repr += ' ${g.table.get_type_name(fn_info.return_type)}'
		}
		g.write('"$repr"')
	} else {
		g.write('"${sym.name}"')
	}
	*/
}
