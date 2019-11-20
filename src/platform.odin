package main

foreign import "system:user32.lib"

@(default_calling_convention = "std")
foreign user32 {
	@(link_name="SetCapture") set_capture  :: proc(hwnd: rawptr) ---;
	@(link_name="ReleaseCapture") release_capture  :: proc(hwnd: rawptr) ---;
	@(link_name="MoveWindow") move_window  :: proc(hwnd: rawptr, x, y, w, h: i32, repaint: b32) ---;
}
