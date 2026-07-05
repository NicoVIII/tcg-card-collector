import shared/driver/http/static_files

// ── resolve_path ──────────────────────────────────────────────────────────────

pub fn root_maps_to_index_html_test() {
  assert static_files.resolve_path("/static", "/") == Ok("/static/index.html")
}

pub fn empty_path_maps_to_index_html_test() {
  assert static_files.resolve_path("/static", "") == Ok("/static/index.html")
}

pub fn nested_file_resolves_test() {
  assert static_files.resolve_path("/static", "/assets/app.js")
    == Ok("/static/assets/app.js")
}

pub fn dot_segments_are_dropped_test() {
  assert static_files.resolve_path("/static", "/./foo/./bar")
    == Ok("/static/foo/bar")
}

pub fn dotdot_is_rejected_test() {
  assert static_files.resolve_path("/static", "/../etc/passwd") == Error(Nil)
}

pub fn percent_encoded_dotdot_is_rejected_test() {
  assert static_files.resolve_path("/static", "/%2e%2e/etc/passwd")
    == Error(Nil)
}

pub fn mixed_case_percent_encoded_dotdot_is_rejected_test() {
  assert static_files.resolve_path("/static", "/%2E%2E/etc/passwd")
    == Error(Nil)
}

pub fn nul_byte_is_rejected_test() {
  assert static_files.resolve_path("/static", "/foo%00bar") == Error(Nil)
}

pub fn backslash_is_rejected_test() {
  assert static_files.resolve_path("/static", "/foo%5Cbar") == Error(Nil)
}

// ── content_type ─────────────────────────────────────────────────────────────

pub fn html_content_type_test() {
  assert static_files.content_type("index.html") == "text/html; charset=utf-8"
}

pub fn js_content_type_test() {
  assert static_files.content_type("app.js") == "application/javascript"
}

pub fn mjs_content_type_test() {
  assert static_files.content_type("app.mjs") == "application/javascript"
}

pub fn css_content_type_test() {
  assert static_files.content_type("style.css") == "text/css"
}

pub fn svg_content_type_test() {
  assert static_files.content_type("logo.svg") == "image/svg+xml"
}

pub fn woff2_content_type_test() {
  assert static_files.content_type("font.woff2") == "font/woff2"
}

pub fn wasm_content_type_test() {
  assert static_files.content_type("module.wasm") == "application/wasm"
}

pub fn unknown_ext_defaults_to_octet_stream_test() {
  assert static_files.content_type("file.xyz") == "application/octet-stream"
}
