module meowparser

pub struct Options {
	long_name   string
	short_name  string
	description string
	needs_value bool
}

pub struct Positional {
	name        string
	description string
	required    bool
}



pub struct ParsedArgs {
	pub mut:
		flags       map[string]bool
		values      map[string]string
		positionals []string
}


pub struct Parser {
	pub mut:
	options []Options
	positionals []Positional
	result  ParsedArgs
}

pub fn (mut p Parser) add_positional(name string, required bool, desc string) {
	p.positionals << Positional{
		name: name
		required: required
		description: desc
	}
}
pub fn new_parser() Parser {
	return Parser{
		options: []Options{}
		result: ParsedArgs{
			flags: map[string]bool{}
			values: map[string]string{}
			positionals: []string{}
		}
	}
}
pub fn (mut p Parser) add_option(long string, short string, needs_value bool, desc string) {
	p.options << Options{
		long_name: long
		short_name: short
		needs_value: needs_value
		description: desc
	}
}

pub fn (mut p Parser) parse(args []string) ! {
	mut i := 0

	for i < args.len {
		arg := args[i]

		if arg.starts_with("--") {
			name := arg[2..]

			mut found := false
			mut opt := Options{}

			for o in p.options {
				if o.long_name == name {
					found = true
					opt = o
					break
				}
			}

			if !found {
				return error("Unknown option --$name")
			}

			if opt.needs_value {
				i++
				if i >= args.len || args[i].starts_with("-") {
					return error("Option --$name requires a value")
				}
				p.result.values[name] = args[i]
			} else {
				p.result.flags[name] = true
			}

		} else if arg.starts_with("-") && arg.len > 1 {
			short := arg[1..]

			mut found := false
			mut opt := Options{}

			for o in p.options {
				if o.short_name == short {
					found = true
					opt = o
					break
				}
			}

			if !found {
				return error("Unknown option -$short")
			}

			if opt.needs_value {
				i++
				if i >= args.len || args[i].starts_with("-") {
					return error("Option -$short requires a value")
				}
				p.result.values[opt.long_name] = args[i]
			} else {
				p.result.flags[opt.long_name] = true
			}

		} else {
			p.result.positionals << arg
		}

		i++
	}

	required_count := p.positionals.filter(it.required).len

	if p.result.positionals.len < required_count {
		return error("Missing required positional arguments")
	}
}
