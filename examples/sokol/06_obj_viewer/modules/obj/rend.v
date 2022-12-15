/**********************************************************************
*
* .obj loader
*
* Copyright (c) 2021 Dario Deledda. All rights reserved.
* Use of this source code is governed by an MIT license
* that can be found in the LICENSE file.
*
* TODO:
**********************************************************************/
module obj

import sokol.gfx
import gg.m4
import math
import stbi

/******************************************************************************
* Texture functions
******************************************************************************/
pub fn create_texture(w int, h int, buf &u8) gfx.Image {
	sz := w * h * 4
	mut img_desc := gfx.ImageDesc{
		width: w
		height: h
		num_mipmaps: 0
		min_filter: .linear
		mag_filter: .linear
		// usage: .dynamic
		wrap_u: .clamp_to_edge
		wrap_v: .clamp_to_edge
		label: &u8(0)
		d3d11_texture: 0
	}
	// comment if .dynamic is enabled
	img_desc.data.subimage[0][0] = gfx.Range{
		ptr: buf
		size: usize(sz)
	}

	sg_img := gfx.make_image(&img_desc)
	return sg_img
}

pub fn destroy_texture(sg_img gfx.Image) {
	gfx.destroy_image(sg_img)
}

pub fn load_texture(file_name string) gfx.Image {
	buffer := read_bytes_from_file(file_name)
	stbi.set_flip_vertically_on_load(true)
	img := stbi.load_from_memory(buffer.data, buffer.len) or {
		eprintln('Texure file: [${file_name}] ERROR!')
		exit(0)
	}
	res := create_texture(int(img.width), int(img.height), img.data)
	img.free()
	return res
}

/******************************************************************************
* Pipeline
******************************************************************************/
pub fn (mut obj_part ObjPart) create_pipeline(in_part []int, shader gfx.Shader, texture gfx.Image) Render_data {
	mut res := Render_data{}
	obj_buf := obj_part.get_buffer(in_part)
	res.n_vert = obj_buf.n_vertex
	res.material = obj_part.part[in_part[0]].material

	// vertex buffer
	mut vert_buffer_desc := gfx.BufferDesc{
		label: 0
	}
	unsafe { vmemset(&vert_buffer_desc, 0, int(sizeof(vert_buffer_desc))) }

	vert_buffer_desc.size = usize(obj_buf.vbuf.len * int(sizeof[Vertex_pnct]()))
	vert_buffer_desc.data = gfx.Range{
		ptr: obj_buf.vbuf.data
		size: usize(obj_buf.vbuf.len * int(sizeof[Vertex_pnct]()))
	}

	vert_buffer_desc.@type = .vertexbuffer
	vert_buffer_desc.label = 'vertbuf_part_${in_part:03}'.str
	vbuf := gfx.make_buffer(&vert_buffer_desc)

	// index buffer
	mut index_buffer_desc := gfx.BufferDesc{
		label: 0
	}
	unsafe { vmemset(&index_buffer_desc, 0, int(sizeof(index_buffer_desc))) }

	index_buffer_desc.size = usize(obj_buf.ibuf.len * int(sizeof[u32]()))
	index_buffer_desc.data = gfx.Range{
		ptr: obj_buf.ibuf.data
		size: usize(obj_buf.ibuf.len * int(sizeof[u32]()))
	}

	index_buffer_desc.@type = .indexbuffer
	index_buffer_desc.label = 'indbuf_part_${in_part:03}'.str
	ibuf := gfx.make_buffer(&index_buffer_desc)

	mut pipdesc := gfx.PipelineDesc{}
	unsafe { vmemset(&pipdesc, 0, int(sizeof(pipdesc))) }
	pipdesc.layout.buffers[0].stride = int(sizeof[Vertex_pnct]())

	// the constants [C.ATTR_vs_a_Position, C.ATTR_vs_a_Color, C.ATTR_vs_a_Texcoord0] are generated by sokol-shdc
	pipdesc.layout.attrs[C.ATTR_vs_a_Position].format = .float3 // x,y,z as f32
	pipdesc.layout.attrs[C.ATTR_vs_a_Normal].format = .float3 // x,y,z as f32
	// pipdesc.layout.attrs[C.ATTR_vs_a_Color].format = .ubyte4n // color as u32
	pipdesc.layout.attrs[C.ATTR_vs_a_Texcoord0].format = .float2 // u,v as f32
	// pipdesc.layout.attrs[C.ATTR_vs_a_Texcoord0].format  = .short2n  // u,v as u16
	pipdesc.index_type = .uint32

	color_state := gfx.ColorState{
		blend: gfx.BlendState{
			enabled: true
			src_factor_rgb: .src_alpha
			dst_factor_rgb: .one_minus_src_alpha
		}
	}
	pipdesc.colors[0] = color_state

	pipdesc.depth = gfx.DepthState{
		write_enabled: true
		compare: .less_equal
	}
	pipdesc.cull_mode = .front

	pipdesc.label = 'pip_part_${in_part:03}'.str

	// shader
	pipdesc.shader = shader

	res.bind.vertex_buffers[0] = vbuf
	res.bind.index_buffer = ibuf
	res.bind.fs_images[C.SLOT_tex] = texture
	res.pipeline = gfx.make_pipeline(&pipdesc)
	// println('Buffers part [$in_part] init done!')

	return res
}

/******************************************************************************
* Render functions
******************************************************************************/
// agregate all the part by materials
pub fn (mut obj_part ObjPart) init_render_data(texture gfx.Image) {
	// create shader
	// One shader for all the model
	shader := gfx.make_shader(C.gouraud_shader_desc(gfx.query_backend()))

	mut part_dict := map[string][]int{}
	for i, p in obj_part.part {
		if p.faces.len > 0 {
			part_dict[p.material] << i
		}
	}
	obj_part.rend_data.clear()
	// println("Material dict: ${obj_part.mat_map.keys()}")

	for k, v in part_dict {
		// println("$k => Parts $v")

		mut txt := texture

		if k in obj_part.mat_map {
			mat_map := obj_part.mat[obj_part.mat_map[k]]
			if 'map_Kd' in mat_map.maps {
				file_name := mat_map.maps['map_Kd']
				if file_name in obj_part.texture {
					txt = obj_part.texture[file_name]
					// println("Texture [${file_name}] => from CACHE")
				} else {
					txt = load_texture(file_name)
					obj_part.texture[file_name] = txt
					// println("Texture [${file_name}] => LOADED")
				}
			}
		}
		// key := obj_part.texture.keys()[0]
		// obj_part.rend_data << obj_part.create_pipeline(v, shader, obj_part.texture[key])
		obj_part.rend_data << obj_part.create_pipeline(v, shader, txt)
	}
	// println("Texture array len: ${obj_part.texture.len}")
	// println("Calc bounding box.")
	obj_part.calc_bbox()
	println('init_render_data DONE!')
}

pub fn (obj_part ObjPart) bind_and_draw(rend_data_index int, in_data Shader_data) u32 {
	// apply the pipline and bindings
	mut part_render_data := obj_part.rend_data[rend_data_index]

	// pass light position
	mut tmp_fs_params := Tmp_fs_param{}
	tmp_fs_params.ligth = in_data.fs_data.ligth

	if part_render_data.material in obj_part.mat_map {
		mat_index := obj_part.mat_map[part_render_data.material]
		mat := obj_part.mat[mat_index]

		// ambient
		tmp_fs_params.ka = in_data.fs_data.ka
		if 'Ka' in mat.ks {
			tmp_fs_params.ka = mat.ks['Ka']
		}

		// specular
		tmp_fs_params.ks = in_data.fs_data.ks
		if 'Ks' in mat.ks {
			tmp_fs_params.ks = mat.ks['Ks']
		}

		//  specular exponent Ns
		if 'Ns' in mat.ns {
			tmp_fs_params.ks.e[3] = mat.ns['Ns'] / 1000.0
		} else {
			// defautl value is 10
			tmp_fs_params.ks.e[3] = f32(10) / 1000.0
		}

		// diffuse
		tmp_fs_params.kd = in_data.fs_data.kd
		if 'Kd' in mat.ks {
			tmp_fs_params.kd = mat.ks['Kd']
		}

		// alpha/transparency
		if 'Tr' in mat.ns {
			tmp_fs_params.kd.e[3] = mat.ns['Tr']
		}
	}

	gfx.apply_pipeline(part_render_data.pipeline)
	gfx.apply_bindings(part_render_data.bind)

	vs_uniforms_range := gfx.Range{
		ptr: in_data.vs_data
		size: usize(in_data.vs_len)
	}
	fs_uniforms_range := gfx.Range{
		ptr: unsafe { &tmp_fs_params }
		size: usize(in_data.fs_len)
	}

	gfx.apply_uniforms(.vs, C.SLOT_vs_params, &vs_uniforms_range)
	gfx.apply_uniforms(.fs, C.SLOT_fs_params, &fs_uniforms_range)
	gfx.draw(0, int(part_render_data.n_vert), 1)
	return part_render_data.n_vert
}

pub fn (obj_part ObjPart) bind_and_draw_all(in_data Shader_data) u32 {
	mut n_vert := u32(0)
	// println("Parts: ${obj_part.rend_data.len}")
	for i, _ in obj_part.rend_data {
		n_vert += obj_part.bind_and_draw(i, in_data)
	}
	return n_vert
}

pub fn (mut obj_part ObjPart) calc_bbox() {
	obj_part.max = m4.Vec4{
		e: [f32(-math.max_f32), -math.max_f32, -math.max_f32, 0]!
	}
	obj_part.min = m4.Vec4{
		e: [f32(math.max_f32), math.max_f32, math.max_f32, 0]!
	}
	for v in obj_part.v {
		if v.e[0] > obj_part.max.e[0] {
			obj_part.max.e[0] = v.e[0]
		}
		if v.e[1] > obj_part.max.e[1] {
			obj_part.max.e[1] = v.e[1]
		}
		if v.e[2] > obj_part.max.e[2] {
			obj_part.max.e[2] = v.e[2]
		}

		if v.e[0] < obj_part.min.e[0] {
			obj_part.min.e[0] = v.e[0]
		}
		if v.e[1] < obj_part.min.e[1] {
			obj_part.min.e[1] = v.e[1]
		}
		if v.e[2] < obj_part.min.e[2] {
			obj_part.min.e[2] = v.e[2]
		}
	}
	val1 := obj_part.max.mod3()
	val2 := obj_part.min.mod3()
	if val1 > val2 {
		obj_part.radius = f32(val1)
	} else {
		obj_part.radius = f32(val2)
	}
	// println("BBox: ${obj_part.min} <=> ${obj_part.max}\nRadius: ${obj_part.radius}")
}
