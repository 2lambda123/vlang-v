module builtin

const (
	mem_prot  = Mm_prot(int(Mm_prot.prot_read) | int(Mm_prot.prot_write))
	mem_flags = Map_flags(int(Map_flags.map_private) | int(Map_flags.map_anonymous))
	page_size = u64(Linux_mem.page_size)
)

fn mm_pages(size u64) u32 {
	pages := (size + u64(4) + u64(Linux_mem.page_size)) / u64(Linux_mem.page_size)
	return u32(pages)
}

fn mm_alloc(size u64) (&byte, Errno) {
	pages := mm_pages(size)
	n_bytes := u64(pages * u32(Linux_mem.page_size))

	a, e := sys_mmap(&byte(0), n_bytes, mem_prot, mem_flags, -1, 0)
	if e == .enoerror {
		unsafe {
			mut ap := &u32(a)
			*ap = pages
			return &byte(a + 4), e
		}
	}
	return &byte(0), e
}

fn mm_free(addr &byte) Errno {
	unsafe {
		ap := &int(addr - 4)
		size := u64(*ap) * u64(Linux_mem.page_size)
		return sys_munmap(ap, size)
	}
}
