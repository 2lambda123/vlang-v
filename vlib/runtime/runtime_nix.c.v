module runtime

fn C.sysconf(name int) i64

// nr_cpus returns the number of virtual CPU cores found on the system.
pub fn nr_cpus() int {
	return int(C.sysconf(C._SC_NPROCESSORS_ONLN))
}

// total_memory returns total physical memory found on the system.
pub fn total_memory() usize {
	$if macos {
		return total_memory_macos()
	}
	page_size := usize(C.sysconf(C._SC_PAGESIZE))
	phys_pages := usize(C.sysconf(C._SC_PHYS_PAGES))
	return page_size * phys_pages
}

// free_memory returns free physical memory found on the system.
pub fn free_memory() usize {
	$if macos {
		return free_memory_macos()
	}
	page_size := usize(C.sysconf(C._SC_PAGESIZE))
	av_phys_pages := usize(C.sysconf(C._SC_AVPHYS_PAGES))
	return page_size * av_phys_pages
}
