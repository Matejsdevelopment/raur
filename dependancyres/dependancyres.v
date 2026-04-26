module dependancyres
import os
import json
import readline
import net.http


const cache_base = os.join_path(os.home_dir(), '.cache', 'raur')
struct AURResponse {
	resultcount int          @[json: 'resultcount']
	results     []AURPackageinfo @[json: 'results']
	error_msg   string       @[json: 'error']
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
pub struct ResolvedDeps {
	pub:
		aur     []string
		pacman  []string
		unknown []string
}

struct Dependancy{
	source string
	name string@[required]
	depends []string
	makedepends []string
	checkdepends []string
}
fn getdepsfromsrcinfo(pkgname string) []string {
	cache_dir := os.join_path(cache_base, pkgname)
	srcinfo_path := os.join_path(cache_dir, ".SRCINFO")
	content := os.read_file(srcinfo_path) or { return [] }
	mut deps := []string{}
	for line in content.split("\n") {
		trimmed := line.trim_space()
		if trimmed.starts_with("depends =") || trimmed.starts_with("makedepends =") {
			raw := trimmed.all_after("=").trim_space()
			dep := raw.all_before(">").all_before("<").all_before("=").trim_space()
			if dep.len > 0 { deps << dep }
		}
	}
	return deps
}

fn getallpacmandeps(dependancylist []string) {
	println(dependancylist)
	mut yesno:=readline.read_line("Do you want to install all the dependancies?(the installation will fail if not)	 Y/n:") or {"yes"}
	mut command := ""
	pkg_string := dependancylist.join(" ")
	if os.getuid() == 0 {
		command="sudo pacman --no-confirm -S ${pkg_string}"
	}
	else {
		command="pacman --no-confirm -S $pkg_string q"
	}
	if yesno.trim_space().to_lower().starts_with("y") {
		os.execute(command)
	}
	else if yesno.trim_space().to_lower().starts_with("n") {
		exit(1)
	}
	else {
		exit(1)
3	}
}
fn checkwhatdepsarealreadyinstalled(dependancylist []string) 	[]string{
	mut listwithoutalreadyinstalledones:= []string{}
	for i := 0; i < dependancylist.len; i++ {
		cmd:= os.execute("${if os.geteuid() != 0 { 'sudo ' } else { '' }} pacman -S ${dependancylist[i]}") //<---------- ----- tuff oneliner(checks if sudo)
		if cmd.exit_code==1 {
			listwithoutalreadyinstalledones << dependancylist[i]
		}
	}
	return listwithoutalreadyinstalledones
}
fn getallaurdeps(dependancylist []string) {
	println(dependancylist)
	mut yesno:=readline.read_line("Do you want to install all the dependancies?(the installation will fail if not)	 Y/n:") or {"yes"}
	mut command := ""


	if yesno.trim_space().to_lower().starts_with("y") {
		os.execute(command)
	}
	else if yesno.trim_space().to_lower().starts_with("n") {
		exit(1)
	}
	else {
		exit(1)
	}
}
fn aurpkgexists(pkgname string) bool {
	url := "https://aur.archlinux.org/rpc/?v=5&type=info&arg=${pkgname}"

	resp := http.get(url) or {
		return false
	}

	if resp.status_code != 200 {
		return false
	}

	data := json.decode(AURResponse, resp.body) or {
		return false
	}

	return if data.resultcount > 0 { true } else { false }
}
fn sortpackagestotheirsources(dependancylist []string)			 ([]string, []string, []string){
	mut pacmandeps:=[]string{}
	mut aurdeps := []string{}
	mut unresolveddeps:=[]string{}
	for i := 0; i < dependancylist.len; i++ {
		result := os.execute('pacman -Si ${dependancylist[i]}/dev/null 2>&1')
		if result.exit_code == 0 {
			pacmandeps << dependancylist[i]
		} else if aurpkgexists(dependancylist[i]) {
			aurdeps << dependancylist[i]
		} else {
			unresolveddeps << dependancylist[i]
		}
		//USE LATER, ITS NICER ↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓ 2.3.2026, gtg rn -_-
		//println(if result.exit_code == 0 { "${dependancylist[i]} [Pacman]" } else { if aurpkgexists(dependancylist[i]) {"${dependancylist[i]} [Aur]"} else {"Error while trying to install dependancy ${dependancylist[i]}, try to install it yourself."} })
	}
	return pacmandeps,aurdeps,unresolveddeps
}

pub fn depstojson(pkgname string)string{
	return json.encode(getdepsfromsrcinfo(pkgname))
}
pub fn resolvepackage(pkgname string) ResolvedDeps {
	root := '/'
	dbpath := '/var/lib/pacman/'
	mut mgr := new_manager(root, dbpath) or {
		eprintln('Failed to init: $err')
		exit(1)
	}

	defer { mgr.free() }

	raw_deps := getdepsfromsrcinfo(pkgname)
	aur_deps, pacman_deps, unknown := sortpackagestotheirsources(raw_deps)

	needed_pacman := checkwhatdepsarealreadyinstalled(pacman_deps)
	needed_aur    := checkwhatdepsarealreadyinstalled(aur_deps)

	getallaurdeps(needed_aur)
	getallpacmandeps(needed_pacman)

	return ResolvedDeps{
		aur:     needed_aur
		pacman:  needed_pacman
		unknown: unknown
	}
}





