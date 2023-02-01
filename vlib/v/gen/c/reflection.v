module c

import v.ast
import v.util

// reflection_string maps string to its idx
fn (mut g Gen) reflection_string(str string) int {
	return unsafe {
		g.reflection_strings[str] or {
			g.reflection_strings[str] = g.reflection_strings.len
			g.reflection_strings.len - 1
		}
	}
}

// gen_reflection_strings generates the reflectino string registration
[inline]
fn (mut g Gen) gen_reflection_strings() {
	for str, idx in g.reflection_strings {
		g.reflection_others.write_string('\tv__reflection__add_string(_SLIT("${str}"), ${idx});\n')
	}
}

// gen_empty_array generates code for empty array
[inline]
fn (g Gen) gen_empty_array(type_name string) string {
	return '__new_array_with_default(0, 0, sizeof(${type_name}), 0)'
}

// gen_functionarg_array generates the code for functionarg argument
[inline]
fn (g Gen) gen_functionarg_array(type_name string, node ast.FnDecl) string {
	if node.params.len == 0 {
		return g.gen_empty_array(type_name)
	}
	mut out := 'new_array_from_c_array(${node.params.len},${node.params.len},sizeof(${type_name}),'
	out += '_MOV((${type_name}[${node.params.len}]){'
	for param in node.params {
		out += '((${type_name}){.name=_SLIT("${param.name}"),.typ=${param.typ.idx()},}),'
	}
	out += '}))'
	return out
}

// gen_functionarg_array generates the code for functionarg argument
[inline]
fn (mut g Gen) gen_function_array(nodes []ast.FnDecl) string {
	type_name := 'v__reflection__Function'

	if nodes.len == 0 {
		return g.gen_empty_array(type_name)
	}

	mut out := 'new_array_from_c_array(${nodes.len},${nodes.len},sizeof(${type_name}),'
	out += '_MOV((${type_name}[${nodes.len}]){'
	for method in nodes {
		out += g.gen_reflection_fndecl(method)
		out += ','
	}
	out += '}))'
	return out
}

// gen_reflection_fndecl generates C code for function declaration
[inline]
fn (mut g Gen) gen_reflection_fndecl(node ast.FnDecl) string {
	mut arg_str := '((v__reflection__Function){'
	v_name := node.name.all_after_last('.')
	arg_str += '.mod_name=_SLIT("${node.mod}"),'
	arg_str += '.name=_SLIT("${v_name}"),'
	arg_str += '.args=${g.gen_functionarg_array('v__reflection__FunctionArg', node)},'
	arg_str += '.file_idx=${g.reflection_string(util.cescaped_path(node.file))},'
	arg_str += '.line_start=${node.pos.line_nr},'
	arg_str += '.line_end=${node.pos.last_line},'
	arg_str += '.is_variadic=${node.is_variadic},'
	arg_str += '.return_typ=${node.return_type.idx()},'
	arg_str += '.receiver_typ=${node.receiver.typ.idx()}'
	arg_str += '})'
	return arg_str
}

// gen_reflection_sym generates C code for TypeSymbol struct
[inline]
fn (g Gen) gen_reflection_sym(tsym ast.TypeSymbol) string {
	kind_name := if tsym.kind in [.none_, .struct_, .enum_, .interface_] {
		tsym.kind.str() + '_'
	} else {
		tsym.kind.str()
	}
	info := g.gen_reflection_sym_info(tsym)
	return '(v__reflection__TypeSymbol){.name=_SLIT("${tsym.name}"),.idx=${tsym.idx},.parent_idx=${tsym.parent_idx},.language=_SLIT("${tsym.language}"),.kind=v__ast__Kind__${kind_name},.info=${info}}'
}

// gen_attrs_array generates C code for []Attr
[inline]
fn (g Gen) gen_attrs_array(attrs []ast.Attr) string {
	if attrs.len == 0 {
		return g.gen_empty_array('string')
	}
	mut out := 'new_array_from_c_array(${attrs.len},${attrs.len},sizeof(string),'
	out += '_MOV((string[${attrs.len}]){'
	for attr in attrs {
		if attr.has_arg {
			out += '_SLIT("${attr.name}=${attr.arg}"),'
		} else {
			out += '_SLIT("${attr.name}"),'
		}
	}
	out += '}))'
	return out
}

// gen_fields_array generates C code for []StructField
[inline]
fn (g Gen) gen_fields_array(fields []ast.StructField) string {
	if fields.len == 0 {
		return g.gen_empty_array('v__reflection__StructField')
	}
	mut out := 'new_array_from_c_array(${fields.len},${fields.len},sizeof(v__reflection__StructField),'
	out += '_MOV((v__reflection__StructField[${fields.len}]){'
	for field in fields {
		out += '((v__reflection__StructField){.name=_SLIT("${field.name}"),.typ=${field.typ.idx()},.attrs=${g.gen_attrs_array(field.attrs)},.is_pub=${field.is_pub},.is_mut=${field.is_mut}}),'
	}
	out += '}))'
	return out
}

// gen_type_array generates C code for []Type
[inline]
fn (g Gen) gen_type_array(types []ast.Type) string {
	mut out := 'new_array_from_c_array(${types.len},${types.len},sizeof(int),'
	out += '_MOV((int[${types.len}]){${types.map(it.idx().str()).join(',')}}))'
	return out
}

// gen_string_array generates C code for []string
[inline]
fn (g Gen) gen_string_array(strs []string) string {
	if strs.len == 0 {
		return g.gen_empty_array('string')
	}
	mut out := 'new_array_from_c_array(${strs.len},${strs.len},sizeof(string),'
	items := strs.map('_SLIT("${it}")').join(',')
	out += '_MOV((string[${strs.len}]){${items}}))'
	return out
}

// gen_reflection_sym_info generates C code for TypeSymbol's info sum type
[inline]
fn (g Gen) gen_reflection_sym_info(tsym ast.TypeSymbol) string {
	match tsym.kind {
		.sum_type {
			info := tsym.info as ast.SumType
			s := 'ADDR(v__reflection__SumType, (((v__reflection__SumType){.parent_idx = ${info.parent_type.idx()},.variants=${g.gen_type_array(info.variants)}})))'
			return '(v__reflection__TypeInfo){._v__reflection__SumType = memdup(${s},sizeof(v__reflection__SumType)),._typ=${g.table.find_type_idx('v.reflection.SumType')}}'
		}
		.struct_ {
			info := tsym.info as ast.Struct
			attrs := g.gen_attrs_array(info.attrs)
			fields := g.gen_fields_array(info.fields)
			s := 'ADDR(v__reflection__Struct, (((v__reflection__Struct){.parent_idx = ${(tsym.info as ast.Struct).parent_type.idx()},.attrs=${attrs},.fields=${fields}})))'
			return '(v__reflection__TypeInfo){._v__reflection__Struct = memdup(${s},sizeof(v__reflection__Struct)),._typ=${g.table.find_type_idx('v.reflection.Struct')}}'
		}
		.enum_ {
			info := tsym.info as ast.Enum
			vals := g.gen_string_array(info.vals)
			s := 'ADDR(v__reflection__Enum, (((v__reflection__Enum){.vals=${vals},.is_flag=${info.is_flag}})))'
			return '(v__reflection__TypeInfo){._v__reflection__Enum = memdup(${s},sizeof(v__reflection__Enum)),._typ=${g.table.find_type_idx('v.reflection.Enum')}}'
		}
		else {
			s := 'ADDR(v__reflection__Struct, (((v__reflection__Struct){.parent_idx = ${tsym.parent_idx},})))'
			return '(v__reflection__TypeInfo){._v__reflection__Struct = memdup(${s},sizeof(v__reflection__Struct)),._typ=${g.table.find_type_idx('v.reflection.None')}}'
		}
	}
}

// gen_reflection_function generates C code for reflection function metadata
[inline]
fn (mut g Gen) gen_reflection_function(node ast.FnDecl) {
	if !g.has_reflection {
		return
	}
	func_struct := g.gen_reflection_fndecl(node)
	g.reflection_funcs.write_string('\tv__reflection__add_func(${func_struct});\n')
}

// gen_reflection_data generates code to initilized V reflection metadata
fn (mut g Gen) gen_reflection_data() {
	// modules declaration
	for mod_name in g.table.modules {
		g.reflection_others.write_string('\tv__reflection__add_module(_SLIT("${mod_name}"));\n')
	}

	// types declaration
	for full_name, idx in g.table.type_idxs {
		tsym := g.table.sym_by_idx(idx)
		name := full_name.all_after_last('.')
		sym := g.gen_reflection_sym(tsym)
		g.reflection_others.write_string('\tv__reflection__add_type((v__reflection__Type){.name=_SLIT("${name}"),.idx=${idx},.sym=${sym}});\n')
	}

	// interface declaration
	for _, idecl in g.table.interfaces {
		name := idecl.name.all_after_last('.')
		methods := g.gen_function_array(idecl.methods)
		g.reflection_others.write_string('\tv__reflection__add_interface((v__reflection__Interface){.name=_SLIT("${name}"),.typ=${idecl.typ.idx()},.is_pub=${idecl.is_pub},.methods=${methods}});\n')
	}

	// type symbols declaration
	for _, tsym in g.table.type_symbols {
		sym := g.gen_reflection_sym(tsym)
		g.reflection_others.write_string('\tv__reflection__add_type_symbol(${sym});\n')
	}

	g.gen_reflection_strings()

	// funcs meta info filling
	g.writeln(g.reflection_funcs.str())

	// others meta info filling
	g.writeln(g.reflection_others.str())
}
