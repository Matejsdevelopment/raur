module dependancyres

#flag -lalpm
#include <alpm.h>



@[heap]
pub struct AlpmManager {
	mut:
		handle &C.alpm_handle_t = unsafe { nil }
}
pub fn C.alpm_initialize(root &char, dbpath &char, err &int) &C.alpm_handle_t
fn (am &AlpmManager) get_error() string {
	if isnil(am.handle) { return 'Uninitialized handle' }
	unsafe {
		err_code := C.alpm_errno(am.handle)
		return cstring_to_vstring(C.alpm_strerror(err_code))
	}
}


pub fn (mut m AlpmManager) free() {
	if !isnil(m.handle) {
		C.alpm_release(m.handle)
	}
}

pub fn new_manager(root string, dbpath string) !&AlpmManager {
	mut err := 0
	h := C.alpm_initialize(root.str, dbpath.str, &err)

	if isnil(h) {
		msg := unsafe { cstring_to_vstring(C.alpm_strerror(err)) }
		return error('ALPM ($err): $msg')
	}

	return &AlpmManager{
		handle: h
	}
}
/*
fn main() {
	root := '/'
	dbpath := '/var/lib/pacman/'

	mut mgr := new_manager(root, dbpath) or {
		eprintln('Failed to init: $err')
		return
	}

	defer { mgr.free() }
}*/
pub  struct C.alpm_handle_t {}
pub struct C.alpm_errno_t {}

pub struct C.alpm_db_t {}
pub struct C.alpm_pkg_t {}
pub struct C.alpm_trans_t {}

pub fn C.alpm_get_localdb(handle &C.alpm_handle_t) &C.alpm_db_t
pub fn C.alpm_db_get_pkg(db &C.alpm_db_t, name &char) &C.alpm_pkg_t
pub fn C.alpm_trans_init(handle &C.alpm_handle_t, flags u32) int
pub fn C.alpm_remove_pkg(handle &C.alpm_handle_t, pkg &C.alpm_pkg_t) int
pub fn C.alpm_trans_prepare(handle &C.alpm_handle_t, data &voidptr) int
pub fn C.alpm_trans_commit(handle &C.alpm_handle_t, data &voidptr) int
pub fn C.alpm_trans_release(handle &C.alpm_handle_t) int

pub fn (am &AlpmManager) removepackage(pkg_name string) ! {
	db := C.alpm_get_localdb(am.handle)
	if isnil(db) {
		return error('failed to get local db: ${am.get_error()}')
	}

	pkg := C.alpm_db_get_pkg(db, pkg_name.str)
	if isnil(pkg) {
		return error('package "${pkg_name}" not found: ${am.get_error()}')
	}

	if C.alpm_trans_init(am.handle, 0) != 0 {
		return error('failed to init transaction: ${am.get_error()}')
	}
	defer { C.alpm_trans_release(am.handle) }

	if C.alpm_remove_pkg(am.handle, pkg) != 0 {
		return error('failed to queue removal: ${am.get_error()}')
	}

	if C.alpm_trans_prepare(am.handle, unsafe { nil }) != 0 {
		return error('failed to prepare transaction: ${am.get_error()}')
	}

	if C.alpm_trans_commit(am.handle, unsafe { nil }) != 0 {
		return error('failed to commit transaction: ${am.get_error()}')
	}
}
pub fn C.alpm_pkg_vercmp(&char, &char) int

pub fn C.alpm_release(handle &C.alpm_handle_t) int
pub fn C.alpm_errno(handle &C.alpm_handle_t) int
pub fn C.alpm_strerror(err int) &char
pub fn (mut am AlpmManager) alpmfree() {
	unsafe {
		if !isnil(am.handle) {
			C.alpm_release(am.handle)
			am.handle = nil
		}
	}
}