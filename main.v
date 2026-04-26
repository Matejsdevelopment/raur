module main

import os
import readline
import net.http
import json
import meowparser
import term
import dependancyres










const aur_rpc = 'https://aur.archlinux.org/rpc/v5'
const cache_base = os.join_path(os.home_dir(), '.cache', 'raur')

const reset  = '\033[0m'
const bold   = '\033[1m'
const red    = '\033[31m'
const green  = '\033[32m'
const yellow = '\033[33m'
const blue   = '\033[34m'
const cyan   = '\033[36m'

fn c(color string, text string) string {
	return '${color}${text}${reset}'
}


struct AURPackage {
	name           string @[json: 'Name']
	version        string @[json: 'Version']
	description    string @[json: 'Description']
	depends        []string @[json: 'Depends']
	make_depends   []string @[json: 'MakeDepends']
	package_base   string @[json: 'PackageBase']
	url_path       string @[json: 'URLPath']
}

struct AURPackageinfo {
	name        string @[json: 'Name']
	version     string @[json: 'Version']
	description string @[json: 'Description']
	url         string @[json: 'URL']
	num_votes   int    @[json: 'NumVotes']
	popularity  f64    @[json: 'Popularity']
	maintainer  string @[json: 'Maintainer']
	out_of_date int    @[json: 'OutOfDate']
}


struct AURResponse {
	resultcount int          @[json: 'resultcount']
	results     []AURPackageinfo @[json: 'results']
	error_msg   string       @[json: 'error']
}

pub fn searchaur(query string) {
	resp := http.get('${aur_rpc}/search/${query}') or {
		panic('Failed to search the AUR\ngot: ${err}')
	}
	decoded := json.decode(AURResponse, resp.body) or {
		panic('Failed to parse response: ${err}')
	}
	if decoded.error_msg != '' {
		panic('AUR error: ${decoded.error_msg}')
	}
	if decoded.results.len == 0 {
		println('No results found.')
		return
	}
	limit := if decoded.results.len > 25 { 25 } else { decoded.results.len }
	for i in 0 .. limit {
		r := decoded.results[i]
		installed_tag := if is_installed(r.name) { c(green, ' [installed]') } else { '' }
		ood_tag := if r.out_of_date != 0 { c(red, ' [out of date]') } else { '' }
		desc := if r.description.len > 80 { r.description[..77] + '...' } else { r.description }
		pkg_label := c(blue, 'aur/' + r.name)
		votes := c(yellow, '(+${r.num_votes} ★)')
		println('${pkg_label} ${c(green, r.version)}${installed_tag}${ood_tag}')
		println('    ${votes}  ${desc}')
	}
	if decoded.results.len > limit {
		println('  ... and ${decoded.results.len - limit} more results')
	}
}
fn fetchaurinfo(package_names []string) !AURResponse {
	base_url := 'https://aur.archlinux.org/rpc/?v=5&type=info'

	mut query := ''
	for name in package_names {
		//query += '&arg[]=' + url.query_escape(name)
	}

	resp := http.get(base_url + query)!

	if resp.status_code != 200 {
		return error('AUR API returned status $resp.status_code')
	}

	return json.decode(AURResponse, resp.body)!
}
fn infoaur(pkg string) !AURPackageinfo {
	resp := http.get('${aur_rpc}/info/${pkg}') or {
		return error('network error: ${err}')
	}
	decoded := json.decode(AURResponse, resp.body) or {
		return error('failed to parse response: ${err}')
	}
	if decoded.error_msg != '' {
		return error('AUR error: ${decoded.error_msg}')
	}
	if decoded.results.len == 0 {
		return error('package not found: ${pkg}')
	}
	return decoded.results[0]
}

fn is_installed(pkg string) bool {
	return os.execute('pacman -Q ${pkg}').exit_code == 0
}

fn installed_version(pkg string) string {
	res := os.execute('pacman -Q ${pkg}')
	if res.exit_code != 0 { return '' }
	parts := res.output.trim_space().split(' ')
	return if parts.len >= 2 { parts[1] } else { '' }
}

fn checkifpackageisalreadycloned(pkgname string) bool {
	return os.exists(os.join_path(cache_base, pkgname))
}

pub fn clonepkgfromgit(pkgname string) {
	cache_dir := os.join_path(cache_base, pkgname)
	if checkifpackageisalreadycloned(pkgname) {
		println(c(cyan, ':: ') + 'Pulling latest ${pkgname}...')
		res := os.execute('git -C ${cache_dir} pull')
		if res.exit_code != 0 {
			panic('git pull failed:\n${res.output}')
		}
		return
	}
	println(c(cyan, ':: ') + 'Cloning https://aur.archlinux.org/${pkgname}.git...')
	res := os.execute('git clone https://aur.archlinux.org/${pkgname}.git ${cache_dir}')
	if res.exit_code != 0 {
		panic("Failed to clone 'https://aur.archlinux.org/${pkgname}.git'")
	}
}


pub fn checkifpkgisinstalled(target string) bool {
	path := '/var/lib/pacman/local/'
	folders := os.ls(path) or { return false }

	for folder in folders {
		if folder.starts_with(target + '-') {
			return true
		}


		desc_path := os.join_path(path, folder, 'desc')
		lines := os.read_lines(desc_path) or { continue }

		mut inside_provides := false
		for line in lines {
			if line == '%PROVIDES%' {
				inside_provides = true
				continue
			}
			if line.starts_with('%') {
				inside_provides = false
				continue
			}
			if inside_provides && line.trim_space() == target {
				return true
			}
		}
	}
	return false
}
pub fn checkmkpkgfirstandbuild(pkgname string) bool {
	cache_dir := os.join_path(cache_base, pkgname)
	pkgbuild_path := os.join_path(cache_dir, 'PKGBUILD')
	srcinfo_path := os.join_path(cache_dir, '.SRCINFO')

	if !os.exists(pkgbuild_path) {
		eprintln(c(red, 'PKGBUILD not found in ${cache_dir}'))
		return false
	}

	pkgbuild := os.read_file(pkgbuild_path) or {
		eprintln(c(red, 'Failed to read PKGBUILD'))
		return false
	}

	println(c(yellow, 'PKGBUILD:'))
	println(pkgbuild)

	if os.exists(srcinfo_path) {
		srcinfo := os.read_file(srcinfo_path) or { '' }
		if srcinfo.len > 0 {
			println(c(yellow, '.SRCINFO:'))
			println(srcinfo)
		}
	}


	answer := readline.read_line('Proceed with build? [y/N]: ') or { return false }
	if answer.trim_space().to_lower() !in ['y', 'yes'] {
		println('Aborted.')
		return false
	}

	println(c(cyan, ':: ') + 'Running makepkg...')
	res := os.system('cd ${cache_dir} && makepkg -si --needed')
	if res != 0 {
		eprintln(c(red, 'Build failed.'))
		return false
	}
	return true
}

pub struct ResolvedDeps {
	pub:
	aur     []string
	pacman  []string
	unknown []string
}
fn main() {
	mut parser :=meowparser.new_parser()

	parser.add_option("debug","d",false,"Debug mode .") // if its found in parser.results, then the value is then its true TODO: uprade the meowparser library to support types.
	parser.add_option("Sync","S",true,"Sync"	)
	parser.add_option("Remove","R",true,"Remove a package from your system")
	parser.add_option("search","s", true , "Search packages on the AUR!")

	args := os.args[1..]

	parser.parse(args) or {
		eprintln(err)
		return
	}
	dependancyres.setdebugmode("debug" in parser.result.flags)

	dependancyres.debugprint("Flags: $parser.result.flags")
	dependancyres.debugprint("Values: $parser.result.values")
	dependancyres.debugprint("Positionals: $parser.result.positionals")

	if os.getuid() == 0 {
		println(term.yellow('Warning: avoid using Raur with root.'))
	}

	if "Sync" in parser.result.values {
		pkgname := parser.result.values["Sync"]
		clonepkgfromgit(pkgname) //clone it from git
		dependancyres.resolvepackage(pkgname) // resolve all dependancies
		checkmkpkgfirstandbuild(pkgname) // check the make pkg file and build the package
	}
	if "Remove" in parser.result.values{

		mut mgr := dependancyres.new_manager('/', '/var/lib/pacman/') or {
			eprintln(err)
			return
		}

		mgr.removepackage(parser.result.values["Remove"]) or {
			eprintln(err)
			return
		}
		defer { mgr.free() }
	}
	if "search" in parser.result.values {
		searchaur(parser.result.values["search"])
	}
	if parser.result.values.len == 0 {
		print("Use raur -h for help")
	}


}
