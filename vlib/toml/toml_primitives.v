// Sorry! This Libary Compliant is v0.4.0.
// based by https://github.com/cktan/tomlc99
// (c) 2019 keito940 All Rights Reserved.

module toml

#flag -I @VROOT/thirdparty/tomlc99
#flag @VROOT/thirdparty/tomlc99/toml.o
#include "toml.h"

struct &C.toml{
	str			&C.toml_toml_rtos
	intger		&C.toml.toml_rtoi
	boolean 	&C.toml.toml_rtob
	double		&C.toml.toml_rtod
	dbl_str 	&C.toml.toml_rtod_ex
	raw_ts		&C.toml.toml_rtots
	table		&C.toml.toml_table_t
	array		&C.toml.toml_array_t
	time_stamp	&C.toml.toml_timestamp_t
}

fn tomldecode_str (root &C.toml) string{
	// error check.
	err := root.str(root,rtn)
	if err = -1 {
		return ""
	}
	return rtn
}

fn tomldecode_int (root &C.toml) int{
	// error check.
	err := root.intger(root,rtn)
	if err = -1 {
		return 0
	}

	return rtn
}

fn tomldecode_bool (root &C.toml) bool{
	// error check.
	err := root.boolean(root,rtn)
	if err = -1 {
		return false
	}

	if rtn = 1 {
		return true
	}
	else {
		return false
	}
}

fn tomldecode_i8 (root &C.toml) i8{
	//error check.
	err := root.intger(root,rtn)
	if err = -1 {
		return 0
	}
	return rtn
}

fn tomldecode_i16 (root &C.toml) i16{
	// error check.
	err := root.intger(root,rtn)
	if err = -1{
		return 0
	}

	return rtn
}

fn tomldecode_i64 (root &C.toml) i64{
	// error check.
	err := root.intger(root,rtn)
	if err = -1  {
		return 0
	}

	return rtn
}

// Time Stamp Decode.
fn tomldecode_ts (root &C.toml) &C.toml_timestamp_t{
	err := root.raw_ts(root.rtn)
	if err = -1 {
		return 0
	}

	return rtn
}