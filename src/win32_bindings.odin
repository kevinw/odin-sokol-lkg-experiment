package main

foreign import "system:user32.lib"
import "core:sys/win32"

@(default_calling_convention = "std")
foreign user32 {
    FindWindowW :: proc(class_name, window_name: win32.Wstring) -> win32.Hwnd ---
    FindWindowExW :: proc(parent, child_after: win32.Hwnd, class_name, window_name: win32.Wstring) -> win32.Hwnd ---
    SendMessageW :: proc(hwnd: win32.Hwnd, msg: u32, wparam: win32.Wparam, lparam: win32.Lparam) -> win32.Hwnd ---
    CallWindowProcW :: proc(wnd_proc: win32.Wnd_Proc, hwnd: win32.Hwnd, msg: u32, wparam: win32.Wparam, lparam: win32.Lparam) -> win32.Hwnd ---
}
@private WM_COPYDATA :: 0x004A;

COPYDATASTRUCT :: struct { dw_data: rawptr, size: u32, lp_data: rawptr }
