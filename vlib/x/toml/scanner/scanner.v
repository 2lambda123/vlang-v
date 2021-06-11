// Copyright (c) 2019-2021 Alexander Medvednikov. All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.
module scanner

import os
import math.mathutil
import x.toml.input
import x.toml.token

// Scanner contains the necessary fields for the state of the scan process.
// the task the scanner does is also refered to as "lexing" or "tokenizing".
// The Scanner methods are based on much of the work in `vlib/strings/textscanner`.
pub struct Scanner {
pub:
	config Config
	text   string // the input TOML text
mut:
	col     int // current column number (x coordinate)
	line_nr int = 1 // current line number (y coordinate)
	pos     int // current flat/index position in the `text` field
	mode    Mode // sub-mode of the scanner
}

enum Mode {
	normal
	inside_string
}

// Config is used to configure a Scanner instance.
// Only one of the fields `text` and `file_path` is allowed to be set at time of configuration.
pub struct Config {
pub:
	input input.Config
	tokenize_formating bool // if true, generate tokens for `\n`, ` `, `\t`, `\r` etc.
}

// new_scanner returns a new heap allocated `Scanner` instance.
pub fn new_scanner(config Config) &Scanner {
	config.input.validate()
	mut text := config.input.text
	file_path := config.input.file_path
	if os.is_file(file_path) {
		text = os.read_file(file_path) or {
			panic(@MOD + '.' + @FN + ' Could not read "$file_path": "$err.msg"')
		}
	}
	mut s := &Scanner{
		config: config
		text: text
	}
	return s
}

[direct_array_access]
pub fn (mut s Scanner) scan() token.Token {
	for {
		c := s.next()

		if c == -1 || s.pos == s.text.len{
			s.inc_line_number()
			return s.new_token(.eof, '', 1)
		}

		ascii := byte(c).ascii_str()
		eprintln(@MOD + '.' + @FN + ' current char "$ascii"')

		if is_name_char(byte(c)) {
			name := ascii+s.ident_name()
			eprintln(@MOD + '.' + @FN + ' identified a name "$name"')
			return s.new_token(.name, name, name.len)
		}
		match rune(c) {
			` `, `\t`, `\n` {
				eprintln(@MOD + '.' + @FN + ' identified one of " ", "\\t" or "\\n" ("$ascii")')
				if s.config.tokenize_formating {
					mut kind := token.Kind.whitespace
					if c == `\t` {
						kind = token.Kind.tab
					}
					if c == `\n` {
						kind = token.Kind.nl
					}
					return s.new_token(kind, ascii, ascii.len)
				}
				if c == `\n` {
					s.inc_line_number()
					eprintln(@MOD + '.' + @FN + ' incremented line nr to $s.line_nr')
				}
				continue
			}
			`=` {
				eprintln(@MOD + '.' + @FN + ' identified assign "$ascii"')
				return s.new_token(.assign, ascii, ascii.len)
			}
			`"` { // string"
				ident_string := s.ident_string()
				eprintln(@MOD + '.' + @FN + ' identified string "$ident_string"')
				return s.new_token(.string, ident_string, ident_string.len + 2) // + two quotes
			}
			`#` {
				start := s.pos + 1
				s.ignore_line()
				//s.next()
				hash := s.text[start..s.pos]
				eprintln(@MOD + '.' + @FN + ' identified hash "$hash"')
				return s.new_token(.hash, hash, hash.len + 1)
			}
			else {
				panic(@MOD + '.' + @FN + ' could not scan character code $c ("$ascii") at $s.pos ($s.line_nr,$s.col) "${s.text[s.pos]}"')
			}
		}
	}
	eprintln(@MOD + '.' + @FN + ' unknown character code at $s.pos ($s.line_nr,$s.col) "${s.text[s.pos]}"')
	return s.new_token(.unknown, '', 0)
}

// free frees all allocated resources
[unsafe]
pub fn (mut s Scanner) free() {
	unsafe {
		s.text.free()
	}
}

// remaining returns how many characters remain in the text input
[inline]
pub fn (s &Scanner) remaining() int {
	return s.text.len - s.pos
}

// next returns the next character code from the input text.
// next returns `-1` if it can't reach the next character.
[direct_array_access; inline]
pub fn (mut s Scanner) next() int {
	if s.pos < s.text.len {
		opos := s.pos
		s.pos++
		s.col++
		c := s.text[opos]
		return c
	}
	return -1
}

// skip skips one character ahead.
[inline]
pub fn (mut s Scanner) skip() {
	if s.pos + 1 < s.text.len {
		s.pos++
		s.col++
	}
}

// skip_n skips ahead `n` characters.
// If the skip goes out of bounds from the length of `Scanner.text`,
// the scanner position will be sat to the last character possible.
[inline]
pub fn (mut s Scanner) skip_n(n int) {
	s.pos += n
	s.col += n
	if s.pos > s.text.len {
		s.pos = s.text.len
		s.col = s.text.len
	}
}

// peek returns the *next* character code from the input text.
// peek returns `-1` if it can't peek the next character.
// unlike `next()`, `peek()` does not change the state of the scanner.
[direct_array_access; inline]
pub fn (s &Scanner) peek() int {
	if s.pos < s.text.len {
		return s.text[s.pos]
	}
	return -1
}

// peek_n returns the character code from the input text at position + `n`.
// peek_n returns `-1` if it can't peek `n` characters ahead.
[direct_array_access; inline]
pub fn (s &Scanner) peek_n(n int) int {
	if s.pos + n < s.text.len {
		return s.text[s.pos + n]
	}
	return -1
}

// back goes back 1 character from the current scanner position.
[inline]
pub fn (mut s Scanner) back() {
	if s.pos > 0 {
		s.pos--
		s.col--
	}
}

// back_n goes back `n` characters from the current scanner position.
pub fn (mut s Scanner) back_n(n int) {
	s.pos -= n
	s.col -= n
	if s.pos < 0 {
		s.pos = 0
		s.col = 0
	}
	if s.pos > s.text.len {
		s.pos = s.text.len
		s.col = s.text.len
	}
}

// reset resets the internal state of the scanner.
pub fn (mut s Scanner) reset() {
	s.pos = 0
	s.col = 0
	s.line_nr = 1
}

// new_token returns a new `token.Token`.
[inline]
fn (mut s Scanner) new_token(kind token.Kind, lit string, len int) token.Token {
	//line_offset := 1
	//println('new_token($lit)')
	return token.Token{
		kind: kind
		lit: lit
		col: mathutil.max(1, s.col - len + 1)
		line_nr: s.line_nr //+ line_offset
		pos: s.pos - len + 1
		len: len
	}
}

[inline]
fn (mut s Scanner) ignore_line() {
	s.eat_to_end_of_line()
	s.back()
	//s.inc_line_number()
}

[inline]
fn (mut s Scanner) inc_line_number() {
	s.col = 0
	s.line_nr++
}

[direct_array_access; inline]
fn (mut s Scanner) eat_to_end_of_line() {
	for c := s.next(); c != -1 && c != `\n`; c = s.next() {
		eprintln(@MOD + '.' + @FN + ' skipping "${byte(c).ascii_str()}"')
		continue
	}
}

[direct_array_access; inline]
fn (mut s Scanner) ident_name() string {
	start := s.pos
	s.pos++
	s.col++
	for s.pos < s.text.len {
		c := s.text[s.pos]
		if !(is_name_char(c) || c.is_digit()) {
			break
		}
		s.pos++
		s.col++
	}
	name := s.text[start..s.pos]
	//s.pos--
	return name
}

[direct_array_access]
fn (mut s Scanner) ident_string() string {
	s.pos--
	s.col--
	q := s.text[s.pos]
	start := s.pos
	mut lit := ''
	for {
		s.pos++
		s.col++
		if s.pos >= s.text.len {
			panic(@MOD + '.' + @FN + ' unfinished string literal "${q.ascii_str()}" started at $start ($s.line_nr,$s.col) "${byte(s.text[s.pos]).ascii_str()}"')
			//break
		}
		c := s.text[s.pos]
		eprintln(@MOD + '.' + @FN + 'c: $c / "${c.ascii_str()}" (q: $q)')
		if c == q {
			s.pos++
			s.col++
			return lit
		}
		lit += c.ascii_str()
		//println('lit: "$lit"')
	}
	return lit
}

[inline]
pub fn is_name_char(c byte) bool {
	return (c >= `a` && c <= `z`) || (c >= `A` && c <= `Z`) || c == `_`
}
