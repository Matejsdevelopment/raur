module dependancyres

import os



__global debugmode = false

pub fn setdebugmode(b bool) {
	debugmode = b
	return
}
pub fn debugprint(stringtoprint string) {
	if  debugmode{
		println(stringtoprint)
	}
	return
}


struct LocalDB {
	mut:
	packages map[string]string
}
struct AURPackage {
	mut:
		name           string @[json: 'Name']
		version        string @[json: 'Version']
		description    string @[json: 'Description']
		depends        []string @[json: 'Depends']
		provides	   []string@[json: 'provides']
		make_depends   []string @[json: 'MakeDepends']
		package_base   string @[json: 'PackageBase']
		url_path       string @[json: 'URLPath']
}

pub fn init_alpm() {
	root := '/'
	dbpath := os.join_path(os.home_dir(), '.cache', 'my_alpm_db')

	// Ensure dbpath exists so ALPM can write its lock file
	if !os.exists(dbpath) {
		os.mkdir_all(dbpath) or { panic(err) }
	}

	mut mgr := new_manager(root, dbpath) or {
		eprintln('ALPM Initialization failed: $err')
		return
	}

	defer { mgr.free() }

	debugprint('ALPM initialized successfully!')
}

fn splitdep(dep string) (string, string,string) {
	split := dep.split_any('><=').filter(it != '')

	mut mod := ''
	for c in dep {
		if c in [`>`, `<`, `=`] { mod += c.ascii_str() }
	}

	if split.len == 0 {
		return "", "", ""
	}

	if split.len == 1 {
		return split[0], "", ""
	}

	return split[0], mod, split[1]//reminder!!!!!!: use _,mod,_ when you want to get this
}
pub fn versatisfies(ver1 string, mod string, ver2 string) bool {
	res := unsafe { C.alpm_pkg_vercmp(ver1.str, ver2.str) }

	satisfied := match mod {
		'='  { res == 0 }
		'<'  { res < 0 }
		'<=' { res <= 0 }
		'>'  { res > 0 }
		'>=' { res >= 0 }
		else { false }
	}
	return satisfied
}

fn pkgsatisfies(name string, version string, dep string) bool {
	depname, depmod, depversion := splitdep(dep)

	if depname != name {
		return false
	}

	return versatisfies(version, depmod, depversion)
}



fn parse_pkg_desc(path string) ?AURPackage {
	lines := os.read_lines(path) or { return none }

	mut pkg := AURPackage{}
	mut state := 0 // 0: searching, 1: name, 2: provides

	for line in lines {
		if line.len == 0 {
			state = 0
			continue
		}

		if line[0] == `%` {
			if line == '%NAME%' {
				state = 1
			} else if line == '%PROVIDES%' {
				state = 2
			} else {
				state = 0
			}
			continue
		}

		if state == 1 {
			pkg.name = line
			state = 0
		} else if state == 2 {
			pkg.provides << line
		}
	}
	return pkg
}



pub fn synclocaldb() LocalDB {
	mut db := LocalDB{
		packages: map[string]string{}
	}
	path := '/var/lib/pacman/local/'
	folders := os.ls(path) or { return db }

	for folder in folders {
		desc_path := os.join_path(path, folder, 'desc')
		lines := os.read_lines(desc_path) or { continue }

		mut current_name := ''
		mut current_ver := ''
		mut section := ''

		for line in lines {
			if line.starts_with('%') {
				section = line
				continue
			}
			if line == '' { continue }

			match section {
				'%NAME%' {
					current_name = line
					db.packages[line] = ''
				}
				'%VERSION%' {
					current_ver = line
					if current_name != '' {
						db.packages[current_name] = line
					}
				}
				'%PROVIDES%' {
					db.packages[line] = current_ver
				}
				else {}
			}
		}

	}
	return db
}

