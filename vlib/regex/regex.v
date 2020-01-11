module regex
/*
TODO:
- investigate ? beahvour 
- adapt the .* check
* implement the find function

* ^$ for positional match manage
- flags (match all, ignore case?)
- id for groups storing
* linear scan instead fixed scan
* groups
* verify OR
- flag enable capture
- add no capturing group
- add id to capture groups
*/

pub const(
	V_REGEX_VERSION = "0.9a"      // regex module version

	MAX_CODE_LEN     = 256        // default small base code len for the regex programs
	MAX_QUANTIFIER   = 1073741824 // default max repetitions allowed for the quantifiers = 2^30

	// spaces chars (here only westerns!!) TODO: manage all the spaces from unicode
	SPACES = [` `, `\t`, `\n`, `\r`, `\v`, `\f`]
	// new line chars for now only '\n'
	NEW_LINE_LIST = [`\n`]

	// Results
	NO_MATCH_FOUND          = -1
	
	// Errors
	COMPILE_OK              =  0   // the regex string compiled, all ok
	ERR_CHAR_UNKNOWN        = -2   // the char used is unknow to the system
	ERR_UNDEFINED           = -3   // the compiler symbol is undefined
	ERR_INTERNAL_ERROR      = -4   // Bug in the regex system!!
	ERR_CC_ALLOC_OVERFLOW   = -5   // memory for char class full!!
	ERR_SYNTAX_ERROR        = -6   // syntax error in regex compiling
	ERR_GROUPS_OVERFLOW     = -7   // max number of groups reached
	ERR_GROUPS_MAX_NESTED   = -8   // max number of nested group reached
	ERR_GROUP_NOT_BALANCED  = -9   // group not balanced
)

const(
	//-------------------------------------
	// regex program instructions
	//-------------------------------------
	SIMPLE_CHAR_MASK = u32(0x80000000)   // single char mask
	IST_SIMPLE_CHAR  = u32(0x7FFFFFFF)   // single char instruction, 31 bit available to char

	// char class 11 0100 AA xxxxxxxx
	// AA = 00  regular class
	// AA = 01  Negated class ^ char
	IST_CHAR_CLASS       = 0xD1000000   // MASK
	IST_CHAR_CLASS_POS   = 0xD0000000   // char class normal [abc]
	IST_CHAR_CLASS_NEG   = 0xD1000000   // char class negate [^abc]

	// dot char        10 0110 xx xxxxxxxx
	IST_DOT_CHAR         = 0x98000000   // match any char except \n

	// backslash chars 10 0100 xx xxxxxxxx
	IST_BSLS_CHAR        = 0x90000000   // backslash char

	// OR |            10 010Y xx xxxxxxxx
	IST_OR_BRANCH        = 0x91000000   // OR case

	// groups          10 010Y xx xxxxxxxx
	IST_GROUP_START      = 0x92000000   // group start (
	IST_GROUP_END        = 0x94000000   // group end   )

	// control instructions
	IST_PROG_END         = u32(0x88000000)      //10 0010 xx xxxxxxxx 
	//-------------------------------------
)

/******************************************************************************
*
* General Utilities
*
******************************************************************************/
// utf8util_char_len calculate the length in bytes of a utf8 char
[inline]
fn utf8util_char_len(b byte) int {
	return (( 0xe5000000 >> (( b >> 3 ) & 0x1e )) & 3 ) + 1
}

// get_char get a char from position i and return an u32 with the unicode code
[inline]
fn get_char(in_txt string, i int) (u32,int) {
	char_len := utf8util_char_len(in_txt.str[i])
	mut tmp := 0
	mut ch := u32(0)
	for tmp < char_len {
		ch = (ch << 8) | in_txt.str[i+tmp]
		tmp++
	}
	return ch,char_len
}

// get_charb get a char from position i and return an u32 with the unicode code
[inline]
fn get_charb(in_txt byteptr, i int) (u32,int) {
	char_len := utf8util_char_len(in_txt[i])
	mut tmp := 0
	mut ch := u32(0)
	for tmp < char_len {
		ch = (ch << 8) | in_txt[i+tmp]
		tmp++
	}
	return ch,char_len
}

[inline]
fn is_alnum(in_char byte) bool {
	mut tmp := in_char - `A`
	if tmp >= 0x00 && tmp <= 25 { return true }
	tmp = in_char - `a`
	if tmp >= 0x00 && tmp <= 25 { return true }
	tmp = in_char - `0`
	if tmp >= 0x00 && tmp <= 9  { return true }
	return false
}

[inline]
fn is_not_alnum(in_char byte) bool {
	return !is_alnum(in_char)
}

[inline]
fn is_space(in_char byte) bool {
	return in_char in SPACES
}

[inline]
fn is_not_space(in_char byte) bool {
	return !is_space(in_char)
}

[inline]
fn is_digit(in_char byte) bool {
	tmp := in_char - `0`
	return tmp <= 0x09 && tmp >= 0
}

[inline]
fn is_not_digit(in_char byte) bool {
	return !is_digit(in_char)
}

[inline]
fn is_wordchar(in_char byte) bool {
	return is_alnum(in_char) || in_char == `_`
}

[inline]
fn is_not_wordchar(in_char byte) bool {
	return !is_alnum(in_char)
}

[inline]
fn is_lower(in_char byte) bool {
	tmp := in_char - `a`
	return  tmp >= 0x00 && tmp <= 25
}

[inline]
fn is_upper(in_char byte) bool {
	tmp := in_char - `A`
	return  tmp >= 0x00 && tmp <= 25
}

pub fn (re RE) get_parse_error_string(err int) string {
	match err {
		0                      { return "COMPILE_OK" }
		NO_MATCH_FOUND         { return "NO_MATCH_FOUND" }
		ERR_CHAR_UNKNOWN       { return "ERR_CHAR_UNKNOWN" }      
		ERR_UNDEFINED          { return "ERR_UNDEFINED" } 
		ERR_INTERNAL_ERROR     { return "ERR_INTERNAL_ERROR" }
		ERR_CC_ALLOC_OVERFLOW  { return "ERR_CC_ALLOC_OVERFLOW" }
		ERR_SYNTAX_ERROR       { return "ERR_SYNTAX_ERROR" }
		ERR_GROUPS_OVERFLOW    { return "ERR_GROUPS_OVERFLOW"}
		ERR_GROUPS_MAX_NESTED  { return "ERR_GROUPS_MAX_NESTED"}
		ERR_GROUP_NOT_BALANCED { return "ERR_GROUP_NOT_BALANCED"}
		else { return "ERR_UNKNOWN" }
	}
}

// simple_log default log function
fn simple_log(txt string) {
	C.fprintf(C.stdout, "%s",txt.str)
	C.fflush(stdout)
}

/******************************************************************************
*
* Token Structs
*
******************************************************************************/
struct Token{
mut:
	ist u32 = u32(0)

	// Quantifiers / branch
	rep_min         int = 0		  // used also for jump next in the OR branch [no match] pc jump
	rep_max         int = 0		  // used also for jump next in the OR branch [   match] pc jump

	// Char class
	cc_index        int = -1

	// counters for quantifier check (repetitions)
	rep int = 0

	// validator function pointer and control char
	validator fn (byte) bool
	v_ch u32 = u32(0)

	// groups variables
	group_rep          int = 0    // repetition of the group
	group_id           int = -1   // id of the group
	goto_pc            int = -1   // jump to this PC if is needed

	// OR flag for the token 
	next_is_or bool = false       // true if the next token is an OR
}

fn (tok mut Token) reset() {
	tok.rep = 0
}

/******************************************************************************
*
* Regex struct 
*
******************************************************************************/
pub const (
	//F_FND = 0x00000001  // check until the end of the input string, it act like a "find first match", not efficient!!
	//F_NL  = 0x00000002  // end the match when find a new line symbol
	//F_PM  = 0x00000004  // partial match: if the source text finish and the match is positive until then return true

	F_MS  = 0x00000008  // match true only if the match is at the start of the string
	F_ME  = 0x00000010  // match true only if the match is at the end of the string 
)

struct StateDotObj{
mut:
	i  int                = 0
	pc int                = 0
	mi int                = 0
	rep int               = 0
	group_stack_index int = -1
}

pub
struct RE {
pub mut:
	prog []Token

	// char classes storage
	cc []CharClass           // char class list
	cc_index int         = 0 // index

	// state index
	state_stack_index int= -1
	state_stack []StateDotObj
	

	// groups
	group_count int      = 0 // number of groups in this regex struct
	groups []int             // groups index results
	group_max_nested int = 3 // max nested group
	group_max int        = 8 // max allowed number of different groups

	// flags
	flag int             = 0 // flag for optional parameters
	pos_flag int         = 0 // positional flag used by $ ^ metachar

	// Debug/log
	debug int            = 0 // enable in order to have the unroll of the code 0 = NO_DEBUG, 1 = LIGHT 2 = VERBOSE
	log_func fn (string) = simple_log  // log function, can be customized by the user
}

// Reset RE object 
fn (re mut RE) reset(){
	re.group_count      = 0
	re.cc_index         = 0
	
	mut i := 0
	for i < re.prog.len {
		re.prog[i].group_rep          = 0 // clear repetition of the group
		re.prog[i].rep                = 0 // clear repetition of the token
		i++
	}
	re.groups = []

	re.state_stack_index = -1
}

/******************************************************************************
*
* Backslashes chars
*
******************************************************************************/
struct BslsStruct {
	ch u32                   // meta char
	validator fn (byte) bool // validator function pointer
}

const(
	BSLS_VALIDATOR_ARRAY = [
		BslsStruct{`w`, is_alnum},
		BslsStruct{`W`, is_not_alnum},
		BslsStruct{`s`, is_space},
		BslsStruct{`S`, is_not_space},
		BslsStruct{`d`, is_digit},
		BslsStruct{`D`, is_not_digit},
		BslsStruct{`a`, is_lower},
		BslsStruct{`A`, is_upper},
	]

	// these chars are escape if preceded by a \
	BSLS_ESCAPE_LIST = [ `\\`,`|`,`.`,`*`,`+`,`{`,`}`,`[`,`]` ]
)

enum BSLS_parse_state {
		start,
		bsls_found,
		bsls_char,
		normal_char
}

// parse_bsls return (index, str_len) BSLS_VALIDATOR_ARRAY index, len of the backslash sequence if present
fn (re RE) parse_bsls(in_txt string, in_i int) (int,int){
	mut status := BSLS_parse_state.start
	mut i := in_i

	for i < in_txt.len {
		// get our char
		char_tmp,char_len := get_char(in_txt,i)
		ch := byte(char_tmp)

		if status == .start && ch == `\\` {
			status = .bsls_found
			i += char_len
			continue
		}

		// check if is our bsls char, for now only one length sequence
		if status == .bsls_found {
			for c,x in BSLS_VALIDATOR_ARRAY {
				if x.ch == ch {
					return c,i-in_i+1
				}
			}
			status = .normal_char
			continue
		}

		// no BSLS validator, manage as normal escape char char
		if status == .normal_char {
			//C.printf("BSLS test escape char\n")
			if ch in BSLS_ESCAPE_LIST {
				//C.printf("BSLS [%c] is an escape char\n",ch)
				return NO_MATCH_FOUND,i-in_i+1
			}
			return ERR_SYNTAX_ERROR,i-in_i+1
		}

		// at the present time we manage only one char after the \
		break

	}
	// not our bslss return KO
	return ERR_SYNTAX_ERROR, i
}

/******************************************************************************
*
* Char class
*
******************************************************************************/
const(
	CC_NULL = 0    // empty cc token
	CC_CHAR = 1    // simple char: a
	CC_INT  = 2    // char interval: a-z
	CC_BSLS = 3    // backslash char
	CC_END  = 4    // cc sequence terminator
)

struct CharClass {
mut:
	cc_type int = CC_NULL      // type of cc token
	ch0 u32     = u32(0)       // first char of the interval a-b  a in this case
	ch1 u32     = u32(0)	   // second char of the interval a-b b in this case
	validator fn (byte) bool   // validator function pointer
}

enum CharClass_parse_state {
	start,
	in_char,
	in_bsls,
	separator,
	finish,
}

fn (re RE) get_char_class(pc int) string {
	buf := [byte(0)].repeat(re.cc.len)
	mut buf_ptr := *byte(&buf)

	mut cc_i := re.prog[pc].cc_index
	mut i := 0
	mut tmp := 0
	for cc_i >= 0 && cc_i < re.cc.len && re.cc[cc_i].cc_type != CC_END {
				
		if re.cc[cc_i].cc_type == CC_BSLS {
			buf_ptr[i++] = `\\`
			buf_ptr[i++] = byte(re.cc[cc_i].ch0)
		}
		else if re.cc[cc_i].ch0 == re.cc[cc_i].ch1 {
			tmp = 3
			for tmp >= 0 {
				x := byte((re.cc[cc_i].ch0 >> (tmp*8)) & 0xFF)
				if x != 0 { 
					buf_ptr[i++] = x
				}
				tmp--
			}
		}
		else {
			tmp = 3
			for tmp >= 0 {
				x := byte((re.cc[cc_i].ch0 >> (tmp*8)) & 0xFF)
				if x != 0 { 
					buf_ptr[i++] = x
				}
				tmp--
			}
			buf_ptr[i++] = `-`
			tmp = 3
			for tmp >= 0 {
				x := byte((re.cc[cc_i].ch1 >> (tmp*8)) & 0xFF)
				if x != 0 { 
					buf_ptr[i++] = x
				}
				tmp--
			}
		}
		cc_i++
	}
	buf_ptr[i] = byte(0)
		
	return tos_clone( buf_ptr )
}

fn (re RE) check_char_class(pc int, ch u32) bool {
	mut cc_i := re.prog[pc].cc_index
	for cc_i >= 0 && cc_i < re.cc.len && re.cc[cc_i].cc_type != CC_END {
		if re.cc[cc_i].cc_type == CC_BSLS {
			if re.cc[cc_i].validator(byte(ch)) {
				//C.printf("CC OK!\n")
				return true
			}
		}
		else if ch >= re.cc[cc_i].ch0 && ch <= re.cc[cc_i].ch1 {
			//C.printf("CC OK!\n")
			return true
		}
		cc_i++
	}
	//C.printf("CC KO!\n")
	return false
}

// parse_char_class return (index, str_len, cc_type) of a char class [abcm-p], char class start after the [ char
fn (re mut RE) parse_char_class(in_txt string, in_i int) (int, int, u32) {
	mut status := CharClass_parse_state.start
	mut i := in_i

	mut tmp_index := re.cc_index
	res_index := re.cc_index

	mut cc_type := u32(IST_CHAR_CLASS_POS)

	for i < in_txt.len {

		// check if we are out of memory for char classes
		if tmp_index >= re.cc.len {
			return ERR_CC_ALLOC_OVERFLOW,0,u32(0) 
		}

		// get our char
		char_tmp,char_len := get_char(in_txt,i)
		ch := byte(char_tmp)

		//C.printf("CC #%3d ch: %c\n",i,ch)

		// negation
		if status == .start && ch == `^` {
			cc_type = u32(IST_CHAR_CLASS_NEG)
			i += char_len
			continue
		}

		// bsls
		if (status == .start || status == .in_char) && ch == `\\` {
			//C.printf("CC bsls.\n")
			status = .in_bsls
			i += char_len
			continue
		}

		if status == .in_bsls {
			//C.printf("CC bsls validation.\n")
			for c,x in BSLS_VALIDATOR_ARRAY {
				if x.ch == ch {
					//C.printf("CC bsls found \\%c.\n",ch)
					re.cc[tmp_index].cc_type   = CC_BSLS
					re.cc[tmp_index].ch0       = BSLS_VALIDATOR_ARRAY[c].ch
					re.cc[tmp_index].ch1       = BSLS_VALIDATOR_ARRAY[c].ch
					re.cc[tmp_index].validator = BSLS_VALIDATOR_ARRAY[c].validator
					i += char_len
					tmp_index++
					status = .in_char
					break
				}
			}
			if status == .in_bsls {
				//C.printf("CC bsls not found \\%c.\n",ch)
				status = .in_char
			}else {
				continue
			}
		}

		// simple char
		if (status == .start || status == .in_char) && 
			ch != `-` && ch != `]` 
		{
			status = .in_char
			
			re.cc[tmp_index].cc_type = CC_CHAR
			re.cc[tmp_index].ch0     = char_tmp
			re.cc[tmp_index].ch1     = char_tmp

			i += char_len
			tmp_index++
			continue
		}

		// check range separator
		if status == .in_char && ch == `-` {
			status = .separator
			i += char_len
			continue
		}

		// check range end
		if status == .separator && ch != `]` && ch != `-` {
			status = .in_char
			re.cc[tmp_index-1].cc_type = CC_INT
			re.cc[tmp_index-1].ch1     = char_tmp
			i += char_len
			continue
		}

		// char class end
		if status == .in_char && ch == `]` {
			re.cc[tmp_index].cc_type = CC_END
			re.cc[tmp_index].ch0     = 0
			re.cc[tmp_index].ch1     = 0
			re.cc_index = tmp_index+1
			
			return res_index, i-in_i+2, cc_type
		}

		i++
	}
	return ERR_SYNTAX_ERROR,0,u32(0)
}

/******************************************************************************
*
* Re Compiler
*
******************************************************************************/
//
// Quantifier
//
enum Quant_parse_state {
	start,
	min_parse,
	comma_checked,
	max_parse,
	finish
}

// parse_quantifier return (min, max, str_len) of a {min,max} quantifier starting after the { char
fn (re RE) parse_quantifier(in_txt string, in_i int) (int, int, int) {
	mut status := Quant_parse_state.start
	mut i := in_i

	mut q_min := 0 // default min in a {} quantifier is 1
	mut q_max := 0 // deafult max in a {} quantifier is MAX_QUANTIFIER

	mut ch := byte(0)

	for i < in_txt.len {
		ch = in_txt.str[i]
		
		//C.printf("%c status: %d\n",ch,status)

		// exit on no compatible char with {} quantifier
		if utf8util_char_len(ch) != 1 {
			return ERR_SYNTAX_ERROR,i,0
		}

		// min parsing skip if comma present
		if status == .start && ch == `,` {
			q_min = 1 // default min in a {} quantifier is 1
			status = .comma_checked
			i++
			continue
		}

		if status == .start && is_digit( ch ) {
			status = .min_parse
			q_min *= 10
			q_min += int(ch - `0`)
			i++
			continue
		}

		if status == .min_parse && is_digit( ch ) {
			q_min *= 10
			q_min += int(ch - `0`)
			i++
			continue
		}

		// we have parsed the min, now check the max
		if status == .min_parse && ch == `,` {
			status = .comma_checked
			i++
			continue
		}

		// single value {4}
		if status == .min_parse && ch == `}` {
			q_max = q_min
			return q_min, q_max, i-in_i+2
		}

		// end without max
		if status == .comma_checked && ch == `}` {
			q_max = MAX_QUANTIFIER
			return q_min, q_max, i-in_i+2
		}

		// start max parsing
		if status == .comma_checked && is_digit( ch ) {
			status = .max_parse
			q_max *= 10
			q_max += int(ch - `0`)
			i++
			continue
		}

		// parse the max
		if status == .max_parse && is_digit( ch ) {
			q_max *= 10
			q_max += int(ch - `0`)
			i++
			continue
		}

		// end the parsing
		if status == .max_parse && ch == `}` {
			return q_min, q_max, i-in_i+2
		}
		
		// not  a {} quantifier, exit
		return ERR_SYNTAX_ERROR,i,0
	}

	// not a conform {} quantifier
	return ERR_SYNTAX_ERROR,i,0
}

//
// main compiler
//
// compile return (return code, index) where index is the index of the error in the query string if return code is an error code
pub fn (re mut RE) compile(in_txt string) (int,int) {
	mut i        := 0
	mut pc       := 0 // program counter
	mut tmp_code := u32(0)

	// group management variables
	mut group_count           := -1
	mut group_stack           := [0 ].repeat(re.group_max_nested)
	mut group_stack_txt_index := [-1].repeat(re.group_max_nested)
	mut group_stack_index     := -1

	i = 0
	for i < in_txt.len {
		tmp_code = u32(0)
		mut char_tmp := u32(0)
		mut char_len := 0
		//C.printf("i: %3d ch: %c\n", i, in_txt.str[i])

		char_tmp,char_len = get_char(in_txt,i)

		//
		// check special cases: $ ^
		//
		if char_len == 1 && i == 0 && byte(char_tmp) == `^` {
			re.pos_flag = F_MS
			i = i + char_len
			continue
		}
		if char_len == 1 && i == (in_txt.len-1) && byte(char_tmp) == `$` {
			re.pos_flag = F_ME
			i = i + char_len
			continue
		}

		// IST_GROUP_START
		if char_len == 1 && pc >= 0 && byte(char_tmp) == `(` {
			
			//check max groups allowed
			if group_count > re.group_max {
				return ERR_GROUPS_OVERFLOW,i+1
			}
			
			group_stack_index++

			// check max nested groups allowed
			if group_stack_index > re.group_max_nested {
				return ERR_GROUPS_MAX_NESTED,i+1
			}

			group_count++

			group_stack_txt_index[group_stack_index] = i
			group_stack[group_stack_index] = pc

			re.prog[pc].ist = u32(0) | IST_GROUP_START
			re.prog[pc].group_id = group_count
			re.prog[pc].rep_min = 1
			re.prog[pc].rep_max = 1
			pc = pc + 1
			i = i + char_len
			continue

		}

		// IST_GROUP_END
		if char_len==1 && pc > 0 && byte(char_tmp) == `)` {
			if group_stack_index < 0 {
				return ERR_GROUP_NOT_BALANCED,i+1
			}

			goto_pc := group_stack[group_stack_index]
			group_stack_index--

			re.prog[pc].ist = u32(0) | IST_GROUP_END
			re.prog[pc].rep_min = 1
			re.prog[pc].rep_max = 1

			re.prog[pc].goto_pc = goto_pc			          // PC where to jump if a group need
			re.prog[pc].group_id = re.prog[goto_pc].group_id  // id of this group, used for storing data
			
			re.prog[goto_pc].goto_pc = pc                     // start goto point to the end group pc
			//re.prog[goto_pc].group_id = group_count         // id of this group, used for storing data

			pc = pc + 1
			i = i + char_len
			continue

		}

		// IST_DOT_CHAR match any char except the following token
		if char_len==1 && pc >= 0 && byte(char_tmp) == `.` {

			/*
			// two consecutive IST_DOT_CHAR are an error
			if pc > 0 && re.prog[pc-1].ist == IST_DOT_CHAR {
				return ERR_SYNTAX_ERROR,i
			}
			*/

			re.prog[pc].ist = u32(0) | IST_DOT_CHAR
			re.prog[pc].rep_min = 1
			re.prog[pc].rep_max = 1
			pc = pc + 1
			i = i + char_len
			continue
		}

		// OR branch
		if char_len==1 && pc > 0 && byte(char_tmp) == `|` {
			// two consecutive IST_DOT_CHAR are an error
			if pc > 0 && re.prog[pc-1].ist == IST_OR_BRANCH {
				return ERR_SYNTAX_ERROR,i
			}
			re.prog[pc].ist = u32(0) | IST_OR_BRANCH
			pc = pc + 1
			i = i + char_len
			continue
		}

		// Quantifiers
		if char_len==1 && pc > 0{
			mut quant_flag := true
			match byte(char_tmp) {
				`?` {
					//C.printf("q: %c\n",char_tmp)
					re.prog[pc-1].rep_min = 0
					re.prog[pc-1].rep_max = 1
				}

				`+` {
					//C.printf("q: %c\n",char_tmp)
					re.prog[pc-1].rep_min = 1
					re.prog[pc-1].rep_max = MAX_QUANTIFIER
				}

				`*` {
					//C.printf("q: %c\n",char_tmp)
					re.prog[pc-1].rep_min = 0
					re.prog[pc-1].rep_max = MAX_QUANTIFIER
				}

				`{` {
					min,max,tmp := re.parse_quantifier(in_txt, i+1)
					// it is a quantifier
					if min >= 0 {
						//C.printf("{%d,%d}\n str:[%s]\n",min,max,in_txt[i..i+tmp])
						i = i + tmp
						re.prog[pc-1].rep_min = min
						re.prog[pc-1].rep_max = max
						continue
					}
					else {
						return min,i
					}
					// TODO: decide if the open bracket can be conform without the close bracket
					/*
					// no conform, parse as normal char
					else {
						quant_flag = false
					}
					*/
				}
				else{
					quant_flag = false
				}
			}

			if quant_flag {
				i = i + char_len
				continue
			}
		}

		// IST_CHAR_CLASS
		if char_len==1 && pc >= 0{
			if byte(char_tmp) == `[` {
				cc_index,tmp,cc_type := re.parse_char_class(in_txt, i+1)
				if cc_index >= 0 {
					//C.printf("index: %d str:%s\n",cc_index,in_txt[i..i+tmp])
					i = i + tmp
					re.prog[pc].ist      = u32(0) | cc_type
					re.prog[pc].cc_index = cc_index
					re.prog[pc].rep_min  = 1
					re.prog[pc].rep_max  = 1
					pc = pc + 1
					continue
				}

				// cc_class vector memory full
				else if cc_index < 0 {
					return cc_index, i
				}
			}
		}
		
		// IST_BSLS_CHAR
		if char_len==1 && pc >= 0{
			if byte(char_tmp) == `\\` {
				bsls_index,tmp := re.parse_bsls(in_txt,i)
				//C.printf("index: %d str:%s\n",bsls_index,in_txt[i..i+tmp])
				if bsls_index >= 0 {
					i = i + tmp
					re.prog[pc].ist       = u32(0) | IST_BSLS_CHAR
					re.prog[pc].rep_min   = 1
					re.prog[pc].rep_max   = 1
					re.prog[pc].validator = BSLS_VALIDATOR_ARRAY[bsls_index].validator
					re.prog[pc].v_ch      = BSLS_VALIDATOR_ARRAY[bsls_index].ch
					pc = pc + 1
					continue
				} 
				// this is an escape char, skip the bsls and continue as a normal char
				else if bsls_index == NO_MATCH_FOUND {
					i += char_len
					char_tmp,char_len = get_char(in_txt,i)
					// continue as simple char
				}
				// if not an escape or a bsls char then it is an error (at least for now!)
				else {
					return bsls_index,i+tmp
				}
			}
		}

		// IST_SIMPLE_CHAR
		tmp_code            = (tmp_code | char_tmp) & IST_SIMPLE_CHAR
		re.prog[pc].ist     = tmp_code
		re.prog[pc].rep_min = 1
		re.prog[pc].rep_max = 1
		//C.printf("char: %c\n",char_tmp)
		pc = pc +1

		i+=char_len
	}

	// add end of the program
	re.prog[pc].ist = IST_PROG_END

	// check for unbalanced groups
	if group_stack_index != -1 {
		return ERR_GROUP_NOT_BALANCED, group_stack_txt_index[group_stack_index]+1
	}

	// check for OR at the end of the program
	if pc > 0 && re.prog[pc-1].ist == IST_OR_BRANCH {
		return ERR_SYNTAX_ERROR,in_txt.len
	}
	
	//******************************************
	// Post processing
	//******************************************

	// count IST_DOT_CHAR
	mut pc1 := 0
	mut tmp_count := 0
	for pc1 < pc {
		if re.prog[pc1].ist == IST_DOT_CHAR {
			tmp_count++
		}
		pc1++
	}
	// init the dot_char stack
	re.state_stack = [StateDotObj{}].repeat(tmp_count+1)
	
	
	// OR branch
	// a|b|cd
	// d exit point
	// a,b,c branches
	pc1 = 0
	for pc1 < pc-2 {
		// two consecutive OR are a syntax error
		if re.prog[pc1+1].ist == IST_OR_BRANCH && re.prog[pc1+2].ist == IST_OR_BRANCH {
			return ERR_SYNTAX_ERROR, i
		}

		// manange a|b chains like a|(b)|c|d...
		// standard solution
		if re.prog[pc1].ist != IST_OR_BRANCH && 
			re.prog[pc1+1].ist == IST_OR_BRANCH &&
			re.prog[pc1+2].ist != IST_OR_BRANCH 
		{
			re.prog[pc1].next_is_or = true   // set that the next token is an  OR
			re.prog[pc1+1].rep_min = pc1+2   // failed match jump
			
			// match jump, if an OR chain the next token will be an OR token
			mut pc2 := pc1+2
			for pc2 < pc-1 {
				ist := re.prog[pc2].ist
				if  ist == IST_GROUP_START {
					//C.printf("Found end group!\n")
					re.prog[pc1+1].rep_max = re.prog[pc2].goto_pc + 1
					break
				}
				if ist != IST_OR_BRANCH {
					//C.printf("Found end group!\n")
					re.prog[pc1+1].rep_max = pc2 + 1
					break
				}
				pc2++
			}
			//C.printf("Compile OR postproc. [%d,OR %d,%d]\n",pc1,pc1+1,pc2)
			pc1 = pc2 
			continue
		}
		
		pc1++
	}

	
	//******************************************
	// DEBUG PRINT REGEX CODE
	//******************************************
	if re.debug > 0 {
		re.log_func(re.get_code())
	}
	//******************************************

	return COMPILE_OK, 0
}

pub fn (re RE) get_code() string {
		mut result := ""
	
		// use the best buffer possible
		mut tmp_len := 256
		if tmp_len < re.cc.len { 
			tmp_len = re.cc.len
		}
		
		buf := [byte(0)].repeat(tmp_len) 
		mut buf_ptr := byteptr(&buf)
		mut pc1 := 0
		C.sprintf(buf_ptr, "========================================\nv RegEx compiler v%s output:\n", V_REGEX_VERSION)
		result += tos_clone(byteptr(&buf))
		
		mut stop_flag := false

		for pc1 <= re.prog.len {
			buf_ptr = byteptr(&buf)
			C.sprintf(buf_ptr, "PC:%3d ist:%08x ",pc1, re.prog[pc1].ist)
			buf_ptr += vstrlen(buf_ptr)
			ist :=re.prog[pc1].ist
			if ist == IST_BSLS_CHAR {
				C.sprintf(buf_ptr, "[\\%c]     BSLS", re.prog[pc1].v_ch)	
			} else if ist == IST_PROG_END {
				C.sprintf(buf_ptr, "PROG_END")
				stop_flag = true
			} else if ist == IST_OR_BRANCH {
				C.sprintf(buf_ptr, "OR      ")
			} else if ist == IST_CHAR_CLASS_POS {
				C.sprintf(buf_ptr, "[%s]     CHAR_CLASS_POS", re.get_char_class(pc1))
			} else if ist == IST_CHAR_CLASS_NEG {
				C.sprintf(buf_ptr, "[^]      CHAR_CLASS_NEG[%s]", re.get_char_class(pc1))
			} else if ist == IST_DOT_CHAR {
				C.sprintf(buf_ptr, ".        DOT_CHAR")
			} else if ist == IST_GROUP_START {
				C.sprintf(buf_ptr, "(        GROUP_START #:%d", re.prog[pc1].group_id) 
			} else if ist == IST_GROUP_END {
				C.sprintf(buf_ptr, ")        GROUP_END   #:%d", re.prog[pc1].group_id)
			} else if ist & SIMPLE_CHAR_MASK == 0 {
				C.sprintf(buf_ptr, "[%c]      query_ch", ist & IST_SIMPLE_CHAR)	
			}
			buf_ptr += vstrlen(buf_ptr)

			if re.prog[pc1].rep_max == MAX_QUANTIFIER {
				C.sprintf(buf_ptr, " {%3d,MAX}",re.prog[pc1].rep_min)
			}else{
				if ist == IST_OR_BRANCH {
					C.sprintf(buf_ptr, " if false go: %3d if true go: %3d", re.prog[pc1].rep_min, re.prog[pc1].rep_max)
				} else {
					C.sprintf(buf_ptr, " {%3d,%3d}", re.prog[pc1].rep_min, re.prog[pc1].rep_max)
				}
			}
			buf_ptr += vstrlen(buf_ptr)
			C.sprintf(buf_ptr, "\n")
			buf_ptr += vstrlen(buf_ptr)
			result += tos_clone(byteptr(&buf))
			if stop_flag {
				break
			}
			pc1++
		}

		buf_ptr = byteptr(&buf)
		C.sprintf(buf_ptr, "========================================\n")
		result += tos_clone(byteptr(&buf))

		return result
	
}

// get_query return a string with a reconstruction of the query starting from the regex program code
pub fn (re RE) get_query() string {
	// use the best buffer possible
	mut tmp_len := 256
	if tmp_len < re.cc.len { 
		tmp_len = re.cc.len
	}
	buf := [byte(0)].repeat(tmp_len) 
	mut buf_ptr := byteptr(&buf)

	mut i := 0
	for i < re.prog.len && re.prog[i].ist != IST_PROG_END && re.prog[i].ist != 0{
		ch := re.prog[i].ist

		//C.printf("ty: %08x\n", ch)
		
		// GROUP start
		if ch == IST_GROUP_START {
			if re.debug == 0 {
				C.sprintf(buf_ptr, "(")
			} else {
				C.sprintf(buf_ptr, "#%d(", re.prog[i].group_id)
			}
			buf_ptr += vstrlen(buf_ptr)
			i++
			continue
		}

		// GROUP end
		if ch == IST_GROUP_END {
			C.sprintf(buf_ptr, ")")
			buf_ptr += vstrlen(buf_ptr)
		}

		// OR branch
		if ch == IST_OR_BRANCH {
			C.sprintf(buf_ptr, "|")
			if re.debug > 0 {
				C.sprintf(buf_ptr, "{%d,%d}", re.prog[i].rep_min, re.prog[i].rep_max)
			}
			buf_ptr += vstrlen(buf_ptr)
			i++
			continue
		}

		// char class
		if ch == IST_CHAR_CLASS_NEG || ch == IST_CHAR_CLASS_POS {
			C.sprintf(buf_ptr, "[")
			buf_ptr += vstrlen(buf_ptr)

			if ch == IST_CHAR_CLASS_NEG {
				C.sprintf(buf_ptr, "^")
				buf_ptr += vstrlen(buf_ptr)
			}

			C.sprintf(buf_ptr,"%s", re.get_char_class(i))
			buf_ptr += vstrlen(buf_ptr)

			C.sprintf(buf_ptr, "]")
			buf_ptr += vstrlen(buf_ptr)
		}

		// bsls char
		if ch == IST_BSLS_CHAR {
			C.sprintf(buf_ptr, "\\%c", re.prog[i].v_ch)
			buf_ptr += vstrlen(buf_ptr)
		}

		// IST_DOT_CHAR
		if ch == IST_DOT_CHAR {
			C.sprintf(buf_ptr, ".")
			buf_ptr += vstrlen(buf_ptr)
		}

		// char alone
		if ch & SIMPLE_CHAR_MASK == 0 {
			if byte(ch) in BSLS_ESCAPE_LIST {
				C.sprintf(buf_ptr, "\\")
				buf_ptr += vstrlen(buf_ptr)
			}
			C.sprintf(buf_ptr, "%c", re.prog[i].ist)
			buf_ptr += vstrlen(buf_ptr)
		}

		// quantifier
		if !(re.prog[i].rep_min == 1 && re.prog[i].rep_max == 1) {
			if re.prog[i].rep_min == 0 && re.prog[i].rep_max == 1 {
				C.sprintf(buf_ptr, "?")
			} else if re.prog[i].rep_min == 1 && re.prog[i].rep_max == MAX_QUANTIFIER {
				C.sprintf(buf_ptr, "+")
			} else if re.prog[i].rep_min == 0 && re.prog[i].rep_max == MAX_QUANTIFIER {
				C.sprintf(buf_ptr, "*")
			} else {
				if re.prog[i].rep_max == MAX_QUANTIFIER {
					C.sprintf(buf_ptr, "{%d,MAX}", re.prog[i].rep_min)
				} else {
					C.sprintf(buf_ptr, "{%d,%d}", re.prog[i].rep_min, re.prog[i].rep_max)
				}
			}
			buf_ptr += vstrlen(buf_ptr)
		}

		i++
	}
	C.sprintf(buf_ptr, "\n")
	buf_ptr += vstrlen(buf_ptr)
	return tos_clone(byteptr(&buf))
}

/******************************************************************************
*
* Matching
*
******************************************************************************/
// check_match_token return true if the next token match with the input char
fn (re RE) check_match_token(pc int, ch u32) bool {
	// load the instruction
	ist := re.prog[pc].ist

	// if the IST_DOT_CHAR is the last istruction then capture greedy
	if ist == IST_PROG_END {
		return true
	}

	if ist == IST_CHAR_CLASS_POS || ist == IST_CHAR_CLASS_NEG {
		mut cc_neg := false
			
		if ist == IST_CHAR_CLASS_NEG {
			cc_neg = true
		}

		mut cc_res := re.check_char_class(pc,ch)
		
		if cc_neg {
			cc_res = !cc_res
		}

		return cc_res
	}

	if ist == IST_BSLS_CHAR {
		return re.prog[pc].validator(byte(ch))
	}

	if ist & IST_SIMPLE_CHAR != 0 {
		is_4_byte := (ist & 0x4000000) != 0
		if is_4_byte && (ist | SIMPLE_CHAR_MASK) == ch  {
			return true
		} else {
			if ist == ch {
				return true
			}
		}
	}
	return false
}

enum match_state{
	start = 0,
	stop,
	end,
	
	ist_load,     // load and execute istruction
	ist_next,     // go to next istruction
	ist_next_ks,  // go to next istruction without clenaning the state
	ist_quant_p,  // match positive ,quantifier check 
	ist_quant_n,  // match negative, quantifier check 
	ist_quant_pg, // match positive ,group quantifier check
	ist_quant_ng, // match negative ,group quantifier check
}

fn state_str(s match_state) string {
	match s{
		.start        { return "start" }
		.stop         { return "stop" }
		.end          { return "end" }

		.ist_load     { return "ist_load" }
		.ist_next     { return "ist_next" }
		.ist_next_ks  { return "ist_next_ks" }
		.ist_quant_p  { return "ist_quant_p" }
		.ist_quant_n  { return "ist_quant_n" }
		.ist_quant_pg { return "ist_quant_pg" }
		.ist_quant_ng { return "ist_quant_ng" }
		else { return "UNKN" }
	} 
}

struct StateObj {
pub mut:
	match_flag bool = false
	match_index int = -1
	match_first int = -1
}

pub fn (re mut RE) match_base(in_txt byteptr, in_txt_len int ) (int,int) {
	// result status
	mut result := NO_MATCH_FOUND     // function return
	mut first_match := -1             //index of the first match

	mut i := 0                       // source string index
	mut ch := u32(0)                 // examinated char 
	mut char_len := 0                // utf8 examinated char len
	mut m_state := match_state.start // start point for the matcher FSM

	mut pc := -1                     // program counter
	mut state := StateObj{}          // actual state
	mut ist := u32(0)                // Program Counter

	mut group_stack      := [-1].repeat(re.group_max)
	mut group_data       := [-1].repeat(re.group_max)

	mut group_index := -1            // group id used to know how many groups are open

	mut step_count := 0              // stats for debug
	mut dbg_line   := 0              // count debug line printed
	
	re.reset()

	for m_state != .end {
		
		if pc >= 0 && pc < re.prog.len {
			ist = re.prog[pc].ist
		}else if pc >= re.prog.len {
			C.printf("ERROR!! PC overflow!!\n")
			return ERR_INTERNAL_ERROR, i
		}

		//******************************************
		// DEBUG LOG
		//******************************************
		if re.debug>0 {
			// use the best buffer possible
			mut tmp_len := 256
			if tmp_len < re.cc.len { 
				tmp_len = re.cc.len
			}

			// print all the instructions
			buf := [byte(0)].repeat(tmp_len) 
			mut buf_ptr := byteptr(&buf)

			// print header
			if dbg_line == 0 {
				C.sprintf(buf_ptr, "flags: %08x\n",re.flag)
				buf_ptr += vstrlen(buf_ptr)
				re.log_func(tos_clone(byteptr(&buf)))
				buf_ptr = byteptr(&buf)
			}

			// end of the input text
			if i >= in_txt_len {
				C.sprintf(buf_ptr, "# %3d END OF INPUT TEXT\n",step_count)
				re.log_func(tos_clone(byteptr(&buf)))
			}else{

				// print only the exe istruction
				if (re.debug == 1 && m_state == .ist_load) ||
					re.debug == 2
				{
								
					if ist == IST_PROG_END {
						C.sprintf(buf_ptr, "# %3d PROG_END\n",step_count)
						buf_ptr += vstrlen(buf_ptr)
					}
					else if ist == 0 || m_state in [.start,.ist_next,.stop] {
						C.sprintf(buf_ptr, "# %3d s: %12s PC: NA\n",step_count, state_str(m_state))
						buf_ptr += vstrlen(buf_ptr)
					}else{
						ch, char_len = get_charb(in_txt,i)
						
						tmp_bl:=[byte(ch >> 24), byte((ch >> 16) & 0xFF), byte((ch >> 8) & 0xFF), byte(ch & 0xFF), 0]
						tmp_un_ch := byteptr(&tmp_bl[4-char_len])

						C.sprintf(buf_ptr, "# %3d s: %12s PC: %3d=>%08x i,ch,len:[%3d,'%s',%d] f.m:[%3d,%3d] ",
							step_count, state_str(m_state).str , pc, ist, i, tmp_un_ch, char_len, first_match,state.match_index)
						buf_ptr += vstrlen(buf_ptr)

						if ist & SIMPLE_CHAR_MASK == 0 {
							if char_len < 4 {
								C.sprintf(buf_ptr, "query_ch: [%c]", ist & IST_SIMPLE_CHAR)
							} else {
								C.sprintf(buf_ptr, "query_ch: [%c]", ist | SIMPLE_CHAR_MASK)
							}
							buf_ptr += vstrlen(buf_ptr)
						} else {
							if ist == IST_BSLS_CHAR {
								C.sprintf(buf_ptr, "BSLS [\\%c]",re.prog[pc].v_ch)	
							} else if ist == IST_PROG_END {
								C.sprintf(buf_ptr, "PROG_END")
							} else if ist == IST_OR_BRANCH {
								C.sprintf(buf_ptr, "OR")
							} else if ist == IST_CHAR_CLASS_POS {
								C.sprintf(buf_ptr, "CHAR_CLASS_POS[%s]",re.get_char_class(pc))
							} else if ist == IST_CHAR_CLASS_NEG {
								C.sprintf(buf_ptr, "CHAR_CLASS_NEG[%s]",re.get_char_class(pc))
							} else if ist == IST_DOT_CHAR {
								C.sprintf(buf_ptr, "DOT_CHAR")
							} else if ist == IST_GROUP_START {
								C.sprintf(buf_ptr, "GROUP_START #:%d rep:%d ",re.prog[pc].group_id, re.prog[re.prog[pc].goto_pc].group_rep) 
							} else if ist == IST_GROUP_END {
								C.sprintf(buf_ptr, "GROUP_END   #:%d deep:%d ",re.prog[pc].group_id, group_index)
							}
							buf_ptr += vstrlen(buf_ptr)
						}
						if re.prog[pc].rep_max == MAX_QUANTIFIER {
							C.sprintf(buf_ptr, "{%d,MAX}:%d",re.prog[pc].rep_min,re.prog[pc].rep)
						} else {
							C.sprintf(buf_ptr, "{%d,%d}:%d",re.prog[pc].rep_min,re.prog[pc].rep_max,re.prog[pc].rep)
						}
						buf_ptr += vstrlen(buf_ptr)
						C.sprintf(buf_ptr, " (#%d)\n",group_index)
						buf_ptr += vstrlen(buf_ptr)
					}
				
					re.log_func(tos_clone(byteptr(&buf)))
					step_count++
				}
			}
			dbg_line++
		}
		//******************************************

		// we're out of text, manage it
		if i >= in_txt_len {
			
			// manage groups
			if group_index >= 0 && state.match_index >= 0 {
				//C.printf("End text with open groups!\n")
				// close the groups
				for group_index >= 0 {
					tmp_pc := group_data[group_index]
					re.prog[tmp_pc].group_rep++
					/*
					C.printf("Closing group %d {%d,%d}:%d\n",
						group_index,
						re.prog[tmp_pc].rep_min,
						re.prog[tmp_pc].rep_max,
						re.prog[tmp_pc].group_rep
					)
					*/
					if re.prog[tmp_pc].group_rep >= re.prog[tmp_pc].rep_min{
						start_i   := group_stack[group_index]
	 					group_stack[group_index]=-1

	 					re.groups << re.prog[tmp_pc].group_id
	 					if start_i >= 0 {
	 						re.groups << start_i
	 					} else {
	 						re.groups << 0
	 					}
	 					re.groups << i
 					}

					group_index--
				}
			}

			// manage IST_DOT_CHAR
			if re.state_stack_index >= 0 {
				//C.printf("DOT CHAR text end management!\n")
				// if DOT CHAR is not the last istruction and we are still going, then no match!!
				if pc < re.prog.len && re.prog[pc+1].ist != IST_PROG_END {
					return NO_MATCH_FOUND,0
				}
			}

			m_state == .end
			break
			return NO_MATCH_FOUND,0
		}

		// starting and init
		if m_state == .start {
			pc = -1
			i = 0
			m_state = .ist_next
			continue
		}

		// ist_next
		if m_state == .ist_next {
			pc = pc + 1
			re.prog[pc].reset()
			// check if we are in the program bounds
			if pc < 0 || pc > re.prog.len {
				C.printf("ERROR!! PC overflow!!\n")
				return ERR_INTERNAL_ERROR, i
			}
			
			m_state = .ist_load
			continue
		}

		// ist_next_ks
		if m_state == .ist_next_ks {
			pc = pc + 1
			// check if we are in the program bounds
			if pc < 0 || pc > re.prog.len {
				C.printf("ERROR!! PC overflow!!\n")
				return ERR_INTERNAL_ERROR, i
			}
			
			m_state = .ist_load
			continue
		}

		// load the char
		ch, char_len = get_charb(in_txt,i)

		// check if stop 
		if m_state == .stop {
			//C.printf("Stop!\n")
			//C.printf("State index: %d\n",re.state_stack_index)
			// we are in restore state ,do it and restart
			if re.state_stack_index >= 0 {	
				i = re.state_stack[re.state_stack_index].i
				pc = re.state_stack[re.state_stack_index].pc
				//re.prog[pc].rep = re.state_stack[re.state_stack_index].rep
				state.match_index =	re.state_stack[re.state_stack_index].mi
				group_index = re.state_stack[re.state_stack_index].group_stack_index
				//re.state_stack_index--
				
				m_state = .ist_load
				continue
			}

			if ist == IST_PROG_END { 
				return first_match,i
			}
			
			// exit on no match
			return result,0
		}

		// ist_load
		if m_state == .ist_load {
			
			// program end
			if ist == IST_PROG_END {
				// if we are in match exit well
				if group_index >= 0 && state.match_index >= 0 {
					group_index = -1
				}
								
				m_state = .stop
				continue
			}

			// check GROUP start, no quantifier is checkd for this token!!
			else if ist == IST_GROUP_START {
				group_index++
				group_data[group_index] = re.prog[pc].goto_pc  // save where is IST_GROUP_END, we will use it for escape
				group_stack[group_index]=i                     // index where we start to manage
				//C.printf("group_index %d rep %d\n", group_index, re.prog[re.prog[pc].goto_pc].group_rep)
								
				m_state = .ist_next
				continue
			}

			// check GROUP end
			else if ist == IST_GROUP_END {
				// we are in matching streak
				if state.match_index >= 0 {
					// restore txt index stack and save the group data
					
					//C.printf("g.id: %d group_index: %d\n", re.prog[pc].group_id, group_index)
					if group_index >= 0 {
	 					start_i   := group_stack[group_index]
	 					group_stack[group_index]=-1

	 					re.groups << re.prog[pc].group_id
	 					if start_i >= 0 {
	 						re.groups << start_i
	 					} else {
	 						re.groups << 0
	 					}
	 					re.groups << i
						
					}
					
					re.prog[pc].group_rep++ // increase repetitions
					//C.printf("GROUP %d END %d\n", group_index, re.prog[pc].group_rep) 
					m_state = .ist_quant_pg
					continue
					
				}

				m_state = .ist_quant_ng
				continue			
			}

			// check OR
			else if ist == IST_OR_BRANCH {
				if state.match_index >= 0 {
					pc = re.prog[pc].rep_max
					//C.printf("IST_OR_BRANCH True pc: %d\n", pc)					
				}else{
					pc = re.prog[pc].rep_min
					//C.printf("IST_OR_BRANCH False pc: %d\n", pc)
				}
				re.prog[pc].reset()
				m_state == .ist_load
				continue
			}

			// check IST_DOT_CHAR
			else if ist == IST_DOT_CHAR {
				//C.printf("IST_DOT_CHAR rep: %d\n", re.prog[pc].rep)
				state.match_flag = true

				if first_match < 0 {
					first_match = i
				}
				state.match_index = i
				re.prog[pc].rep++	

				if re.prog[pc].rep == 1 {
					//C.printf("IST_DOT_CHAR save the state %d\n",re.prog[pc].rep)
					// save the state
					re.state_stack_index++
					re.state_stack[re.state_stack_index].pc = pc
					re.state_stack[re.state_stack_index].mi = state.match_index
					re.state_stack[re.state_stack_index].group_stack_index = group_index
				}

				if re.prog[pc].rep >= 1 && re.state_stack_index >= 0 {
					re.state_stack[re.state_stack_index].i  = i + char_len
					//re.state_stack[re.state_stack_index].rep = re.prog[pc].rep
				} 

				// manage * and {0,} quantifier
				if re.prog[pc].rep_min > 0 {
					i += char_len // next char
				}
				
				if re.prog[pc+1].ist !=  IST_GROUP_END {
					m_state = .ist_next
					continue
				} 
				// IST_DOT_CHAR is the last istruction, get all
				else {
					//C.printf("We are the last one!\n")
					pc-- 
					m_state = .ist_next_ks
					continue
				}

			}

			// char class IST
			else if ist == IST_CHAR_CLASS_POS || ist == IST_CHAR_CLASS_NEG {
				state.match_flag = false
				mut cc_neg := false
			
				if ist == IST_CHAR_CLASS_NEG {
					cc_neg = true
				}
				mut cc_res := re.check_char_class(pc,ch)
				
				if cc_neg {
					cc_res = !cc_res
				}

				if cc_res {
					state.match_flag = true
					
					if first_match < 0 {
						first_match = i
					}
					
					state.match_index = i

					re.prog[pc].rep++ // increase repetitions
					i += char_len // next char
					m_state = .ist_quant_p
					continue
				}
				m_state = .ist_quant_n
				continue
			}

			// check bsls
			else if ist == IST_BSLS_CHAR {
				state.match_flag = false
				tmp_res := re.prog[pc].validator(byte(ch))
				//C.printf("BSLS in_ch: %c res: %d\n", ch, tmp_res)
				if tmp_res {
					state.match_flag = true
					
					if first_match < 0 {
						first_match = i
					}
					
					state.match_index = i

					re.prog[pc].rep++ // increase repetitions
					i += char_len // next char
					m_state = .ist_quant_p
					continue
				}
				m_state = .ist_quant_n
				continue
			}

			// simple char IST
			else if ist & IST_SIMPLE_CHAR != 0 {
				//C.printf("IST_SIMPLE_CHAR\n")
				state.match_flag = false

				if (char_len<4 && ist == ch) || 
					(char_len == 4 && (ist | SIMPLE_CHAR_MASK) == ch ) 
				{
					state.match_flag = true
					
					if first_match < 0 {
						first_match = i
					}
					//C.printf("state.match_index: %d\n", state.match_index)
					state.match_index = i

					re.prog[pc].rep++ // increase repetitions
					i += char_len // next char
					m_state = .ist_quant_p
					continue
				}
				m_state = .ist_quant_n
				continue
			}

			/* UNREACHABLE */
			//C.printf("PANIC2!! state: %d\n", m_state)
			return ERR_INTERNAL_ERROR, i
		}

		/***********************************
		* Quantifier management 
		***********************************/
		// ist_quant_ng
		if m_state == .ist_quant_ng {
			
			// we are finished here
			if group_index < 0 {
				//C.printf("Early stop!\n")
				result = NO_MATCH_FOUND
				m_state = .stop
				continue
			}

			tmp_pc := group_data[group_index]    // PC to the end of the group token
			rep    := re.prog[tmp_pc].group_rep  // use a temp variable 
			re.prog[tmp_pc].group_rep = 0        // clear the repetitions

			//C.printf(".ist_quant_ng group_pc_end: %d rep: %d\n", tmp_pc,rep)

			if rep >= re.prog[tmp_pc].rep_min {
				//C.printf("ist_quant_ng GROUP CLOSED OK group_index: %d\n", group_index)
				
				i = group_stack[group_index]
				pc = tmp_pc
				group_index--
				m_state = .ist_next
				continue
			}
			else if re.prog[tmp_pc].next_is_or {
				//C.printf("ist_quant_ng OR Negative branch\n")

				i = group_stack[group_index]
				pc = re.prog[tmp_pc+1].rep_min -1
				group_index--
				m_state = .ist_next
				continue
			}
			else if rep>0 && rep < re.prog[tmp_pc].rep_min {
				//C.printf("ist_quant_ng UNDER THE MINIMUM g.i: %d\n", group_index)
				
				// check if we are inside a group, if yes exit from the nested groups
				if group_index > 0{
					group_index--
					pc = tmp_pc
					m_state = .ist_quant_ng //.ist_next
					continue
				}

				if group_index == 0 {
					group_index--
					pc = tmp_pc // TEST
					m_state = .ist_next
					continue
				}

				result = NO_MATCH_FOUND
				m_state = .stop
				continue
			}
			else if rep==0 && rep < re.prog[tmp_pc].rep_min {
				//C.printf("ist_quant_ng ZERO UNDER THE MINIMUM g.i: %d\n", group_index)

				if group_index > 0{
					group_index--
					pc = tmp_pc
					m_state = .ist_quant_ng //.ist_next
					continue
				}

				result = NO_MATCH_FOUND
				m_state = .stop
				continue
			}

			//C.printf("DO NOT STAY HERE!! {%d,%d}:%d\n", re.prog[tmp_pc].rep_min, re.prog[tmp_pc].rep_max, rep)
			/* UNREACHABLE */
			return ERR_INTERNAL_ERROR, i

		}
		// ist_quant_pg
		else if m_state == .ist_quant_pg {
			//C.printf(".ist_quant_pg\n")
			mut tmp_pc := pc
			if group_index >= 0 {
				tmp_pc = group_data[group_index]			
			}

			rep := re.prog[tmp_pc].group_rep

			if rep < re.prog[tmp_pc].rep_min {
				//C.printf("ist_quant_pg UNDER RANGE\n")
				pc = re.prog[tmp_pc].goto_pc 
				//group_index--
				
				m_state = .ist_next
				continue
			}
			else if rep == re.prog[tmp_pc].rep_max {
				//C.printf("ist_quant_pg MAX RANGE\n")
				re.prog[tmp_pc].group_rep = 0 // clear the repetitions
				group_index--
				m_state = .ist_next
				continue
			}
			else if rep >= re.prog[tmp_pc].rep_min {
				//C.printf("ist_quant_pg IN RANGE group_index:%d\n", group_index)
				pc = re.prog[tmp_pc].goto_pc - 1
				group_index--
				m_state = .ist_next
				continue
			}
			
			/* UNREACHABLE */
			//C.printf("PANIC3!! state: %d\n", m_state)
			return ERR_INTERNAL_ERROR, i
		}
		
		// ist_quant_n
		else if m_state == .ist_quant_n {
			rep := re.prog[pc].rep
			//C.printf("Here!! PC %d is_next_or: %d \n", pc, re.prog[pc].next_is_or)

			// zero quantifier * or ?
			if rep == 0 && re.prog[pc].rep_min == 0 {
				//C.printf("ist_quant_n ZERO RANGE MIN\n")
				m_state = .ist_next // go to next ist
				continue
			}

			// match failed
			else if rep == 0 && re.prog[pc].rep_min > 0 {
				//C.printf("ist_quant_n NO MATCH\n")
				// dummy
			}
			// match + or *
			else if rep >= re.prog[pc].rep_min {
				//C.printf("ist_quant_n MATCH RANGE\n")
				m_state = .ist_next
				continue
			}

			// check the OR if present
			if re.prog[pc].next_is_or {
				//C.printf("OR present on failing\n")
				state.match_index = -1
				m_state = .ist_next
				continue
			}

			// we are in a group manage no match from here
			if group_index >= 0 {
				//C.printf("ist_quant_n FAILED insied a GROUP group_index:%d\n", group_index)
				m_state = .ist_quant_ng
				continue
			}

			// no other options
			//C.printf("NO_MATCH_FOUND\n")
			result = NO_MATCH_FOUND
			m_state = .stop
			continue
			//return NO_MATCH_FOUND, 0 
		}

		// ist_quant_p
		else if m_state == .ist_quant_p {
			rep := re.prog[pc].rep
			
			// clear the actual dot char capture state
			if re.state_stack_index >= 0 {
				//C.printf("Drop the DOT_CHAR state!\n")
				re.state_stack_index--
			}

			// under range
			if rep > 0 && rep < re.prog[pc].rep_min {
				//C.printf("ist_quant_p UNDER RANGE\n")
				m_state = .ist_load // continue the loop
				continue
			}

			// range ok, continue loop
			else if rep >= re.prog[pc].rep_min && rep < re.prog[pc].rep_max {
				//C.printf("ist_quant_p IN RANGE\n")
				m_state = .ist_load
				continue
			}

			// max reached
			else if rep == re.prog[pc].rep_max {
				//C.printf("ist_quant_p MAX RANGE\n")
				m_state = .ist_next
				continue
			}

		}
		/* UNREACHABLE */
		//C.printf("PANIC4!! state: %d\n", m_state)
		return ERR_INTERNAL_ERROR, i
	}

	// Check the results
	if state.match_index >= 0 {
		if group_index < 0 {
			//C.printf("OK match,natural end [%d,%d]\n", first_match, i)
			return first_match, i
		} else {
			//C.printf("Skip last group\n")
			return first_match,group_stack[group_index--]
		}
	}
	//C.printf("NO_MATCH_FOUND, natural end\n")
	return NO_MATCH_FOUND, 0
}

/******************************************************************************
*
* Public functions
*
******************************************************************************/

//
// Inits
//

// regex create a regex object from the query string
pub fn regex(in_query string) (RE,int,int){
	mut re := RE{}
	re.prog = [Token{}].repeat(in_query.len+1)
	re.cc = [CharClass{}].repeat(in_query.len+1)
	re.group_max_nested = 8

	re_err,err_pos := re.compile(in_query)
	return re, re_err, err_pos
}

// new_regex create a REgex of small size, usually sufficient for ordinary use
pub fn new_regex() RE {
	return new_regex_by_size(1)
}

// new_regex_by_size create a REgex of large size, mult specify the scale factor of the memory that will be allocated
pub fn new_regex_by_size(mult int) RE {
	mut re := RE{}
	re.prog = [Token{}].repeat(MAX_CODE_LEN*mult)       // max program length, default 256 istructions
	re.cc = [CharClass{}].repeat(MAX_CODE_LEN*mult)     // char class list
	re.group_max_nested = 3*mult                        // max nested group
	
	return re
}

//
// Matchers
//

pub fn (re mut RE) match_string(in_txt string) (int,int) {
	start, end := re.match_base(in_txt.str,in_txt.len)
	return start, end
}

//
// Finders
//

// find try to find the first match in the input string
pub fn (re mut RE) find(in_txt string) (int,int) {
	mut i := 0
	for i < in_txt.len {
		tmp_txt := in_txt[i..]
		//C.printf("txt:[%s] %d\n",tmp_txt ,i)
		//C.printf("pos_flag: %08x\n", re.pos_flag)
		start, end := re.match_base(tmp_txt.str, tmp_txt.len)
		if start >= 0 && end > start {
			if re.pos_flag == F_MS && (i+start) > 0 {
				return NO_MATCH_FOUND, 0
			}
			if re.pos_flag == F_ME && (i+end) < (in_txt.len-1) {
				return NO_MATCH_FOUND, 0
			}

			return i+start, i+end
		}
		i++
		if re.pos_flag == F_MS && i>0 {
			return NO_MATCH_FOUND, 0
		}
	}
	return NO_MATCH_FOUND, 0
}
