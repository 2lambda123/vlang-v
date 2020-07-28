module cli

import term
import strings
import math

const (
	base_indent_len            = 2
	min_description_indent_len = 20
	spacing                    = 2
)

fn help_flag(with_abbrev bool) Flag {
	sabbrev := if with_abbrev { 'h' } else { '' }
	return Flag{
		flag: .bool
		name: 'help'
		abbrev: sabbrev
		description: 'Prints help information'
	}
}

fn help_cmd() Command {
	return Command{
		name: 'help'
		usage: '<command>'
		description: 'Prints help information'
		execute: print_help_for_command
	}
}

fn print_help_for_command(help_cmd Command) ? {
	if help_cmd.args.len > 0 {
		mut cmd := help_cmd.parent
		for arg in help_cmd.args {
			mut found := false
			for sub_cmd in cmd.commands {
				if sub_cmd.name == arg {
					cmd = &sub_cmd
					found = true
					break
				}
			}
			if !found {
				args := help_cmd.args.join(' ')
				print('invalid command: $args')
				return
			}
		}
		print(cmd.help_message())
	} else {
		if help_cmd.parent != 0 {
			print(help_cmd.parent.help_message())
		}
	}
}

fn (cmd Command) help_message() string {
	mut help := ''
	help += 'Usage: $cmd.full_name()'
	if cmd.flags.len > 0 {
		help += ' [flags]'
	}
	if cmd.commands.len > 0 {
		help += ' [commands]'
	}
	if cmd.usage.len > 0 {
		help += ' $cmd.usage'
	}
	help += '\n\n'
	if cmd.description != '' {
		help += '$cmd.description\n\n'
	}
	mut abbrev_len := 0
	mut name_len := min_description_indent_len
	if cmd.has_abbrev_flags() {
		for flag in cmd.flags {
			abbrev_len = math.int_max(abbrev_len, flag.abbrev.len + spacing + 1) // + 1 for '-' in front
			name_len = math.int_max(name_len, abbrev_len + flag.name.len + spacing + 2) // + 2 for '--' in front
		}
		for command in cmd.commands {
			name_len = math.int_max(name_len, command.name.len + spacing)
		}
	} else {
		for flag in cmd.flags {
			name_len = math.int_max(name_len, abbrev_len + flag.name.len + spacing + 1) // + 1 for '-' in front
		}
		for command in cmd.commands {
			name_len = math.int_max(name_len, command.name.len + spacing)
		}
	}
	if cmd.flags.len > 0 {
		help += 'Flags:\n'
		for flag in cmd.flags {
			mut flag_name := ''
			if flag.abbrev != '' && cmd.has_abbrev_flags() {
				abbrev_indent := ' '.repeat(abbrev_len - flag.abbrev.len - 1) // - 1 for '-' in front
				flag_name = '-$flag.abbrev$abbrev_indent--$flag.name'
			} else if cmd.has_abbrev_flags() {
				abbrev_indent := ' '.repeat(abbrev_len)
				flag_name = '$abbrev_indent--$flag.name'
			} else {
				flag_name = '-$flag.name'
			}
			mut required := ''
			if flag.required {
				required = ' (required)'
			}
			base_indent := ' '.repeat(base_indent_len)
			description_indent := ' '.repeat(name_len - flag_name.len)
			help += '$base_indent$flag_name$description_indent' + pretty_description(flag.description +
				required, base_indent_len + name_len) + '\n'
		}
		help += '\n'
	}
	if cmd.commands.len > 0 {
		help += 'Commands:\n'
		for command in cmd.commands {
			base_indent := ' '.repeat(base_indent_len)
			description_indent := ' '.repeat(name_len - command.name.len)
			help += '$base_indent$command.name$description_indent' + pretty_description(command.description, name_len) +
				'\n'
		}
		help += '\n'
	}
	return help
}

// pretty_description resizes description text depending on terminal width.
// Essentially, smart wrap-around
fn pretty_description(s string, indent_len int) string {
	width, _ := term.get_terminal_size()
	// Don't prettify if the terminal is that small, it won't be pretty anyway.
	if indent_len > width {
		return s
	}
	indent := ' '.repeat(indent_len)
	chars_per_line := width - indent_len
	// Give us enough room, better a little bigger than smaller
	mut acc := strings.new_builder(((s.len / chars_per_line) + 1) * (width + 1))
	for k, line in s.split('\n') {
		if k != 0 {
			acc.write('\n$indent')
		}
		mut i := chars_per_line - 2
		mut j := 0
		for ; i < line.len; i += chars_per_line - 2 {
			for line[i] != ` ` {
				i--
			}
			// indent was already done the first iteration
			if j != 0 {
				acc.write(indent)
			}
			acc.writeln(line[j..i].trim_space())
			j = i
		}
		// We need this even though it should never happen
		if j != 0 {
			acc.write(indent)
		}
		acc.write(line[j..].trim_space())
	}
	return acc.str()
}