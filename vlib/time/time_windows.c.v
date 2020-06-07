// Copyright (c) 2019-2020 Alexander Medvednikov. All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.
module time

#include <time.h>
#include <sysinfoapi.h>

struct C.tm {
	tm_year int
	tm_mon  int
	tm_mday int
	tm_hour int
	tm_min  int
	tm_sec  int
}

struct C._FILETIME

struct SystemTime {
  year 			u16
  month 		u16
  day_of_week 	u16
  day  			u16
  hour 			u16
  minute 		u16
  second 		u16
  millisecond 	u16
}

fn C.GetSystemTimeAsFileTime(lpSystemTimeAsFileTime C._FILETIME)
fn C.FileTimeToSystemTime()
fn C.SystemTimeToTzSpecificLocalTime()

const (
	// start_time is needed on Darwin and Windows because of potential overflows
	start_time 		 	= init_win_time_start()
	freq_time  		 	= init_win_time_freq()
	start_local_time 	= local_as_unix_time()
)

// in most systems, these are __quad_t, which is an i64
struct C.timespec {
	tv_sec  i64
	tv_nsec i64
}


fn C._mkgmtime(&C.tm) time_t

fn C.QueryPerformanceCounter(&u64) C.BOOL

fn C.QueryPerformanceFrequency(&u64) C.BOOL

fn make_unix_time(t C.tm) int {
	return int(C._mkgmtime(&t))
}

fn init_win_time_freq() u64 {
	f := u64(0)
	C.QueryPerformanceFrequency(&f)
	return f
}

fn init_win_time_start() u64 {
	s := u64(0)
	C.QueryPerformanceCounter(&s)
	return s
}

pub fn sys_mono_now() u64 {
	tm := u64(0)
	C.QueryPerformanceCounter(&tm) // XP or later never fail
	return (tm - start_time) * 1_000_000_000 / freq_time
}

// NB: vpc_now is used by `v -profile` .
// It should NOT call *any other v function*, just C functions and casts.
[inline]
fn vpc_now() u64 {
	tm := u64(0)
	C.QueryPerformanceCounter(&tm)
	return tm
}

// local_as_unix_time returns the current local time as unix time
fn local_as_unix_time() int {
	t := C.time(0)
	tm := C.localtime(&t)

	return make_unix_time(tm)
}

// win_now calculates current time using winapi to get higher resolution on windows
// GetSystemTimeAsFileTime is used. It can resolve time down to millisecond
// other more precice methods can be implemented in the future
fn win_now() Time {

	ft_utc := C._FILETIME{}
	C.GetSystemTimeAsFileTime(&ft_utc)

	st_utc := SystemTime{}
	C.FileTimeToSystemTime(&ft_utc, &st_utc)

	st_local := SystemTime{}
	C.SystemTimeToTzSpecificLocalTime(voidptr(0), &st_utc, &st_local)

	t := Time {
		year: st_local.year
		month: st_local.month
		day: st_local.day
		hour: st_local.hour
		minute: st_local.minute
		second: st_local.second
		microsecond: st_local.millisecond*1000
		unix: u64(st_local.unix_time())
	}

	return t
}

// unix_time returns Unix time.
pub fn (st SystemTime) unix_time() int {
	tt := C.tm{
		tm_sec: st.second
		tm_min: st.minute
		tm_hour: st.hour
		tm_mday: st.day
		tm_mon: st.month - 1
		tm_year: st.year - 1900
	}
	return make_unix_time(tt)
}

// dummy to compile with all compilers
pub fn darwin_now() Time {
	return Time{}
}

// dummy to compile with all compilers
pub fn linux_now() Time {
	return Time{}
}

// dummy to compile with all compilers
pub struct C.timeval {
	tv_sec  u64
	tv_usec u64
}
