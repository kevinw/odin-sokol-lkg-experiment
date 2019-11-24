package main

foreign import "system:user32.lib"
using import "core:sys/win32"

@(default_calling_convention = "std")
foreign user32 {
    FindWindowW :: proc(class_name, window_name: Wstring) -> Hwnd ---
    FindWindowExW :: proc(parent, child_after: Hwnd, class_name, window_name: Wstring) -> Hwnd ---
    SendMessageW :: proc(hwnd: Hwnd, msg: u32, wparam: Wparam, lparam: Lparam) -> Hwnd ---
    CallWindowProcW :: proc(wnd_proc: Wnd_Proc, hwnd: Hwnd, msg: u32, wparam: Wparam, lparam: Lparam) -> Hwnd ---
}

@private WM_COPYDATA :: 0x004A;

COPYDATASTRUCT :: struct { dw_data: rawptr, size: u32, lp_data: rawptr }
