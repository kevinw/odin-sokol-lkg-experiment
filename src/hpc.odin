package main

import "core:fmt"
using import "core:sys/win32"

foreign import "system:user32.lib"

@(default_calling_convention = "std")
foreign user32 {
    FindWindowW :: proc(class_name, window_name: Wstring) -> Hwnd ---
    FindWindowExW :: proc(parent, child_after: Hwnd, class_name, window_name: Wstring) -> Hwnd ---
    SendMessageW :: proc(hwnd: Hwnd, msg: u32, wparam: Wparam, lparam: Lparam) -> Hwnd ---
    CallWindowProcW :: proc(wnd_proc: Wnd_Proc, hwnd: Hwnd, msg: u32, wparam: Wparam, lparam: Lparam) -> Hwnd ---
}

@private WM_COPYDATA :: 0x004A;

@private orig_wnd_proc: Wnd_Proc;

COPYDATASTRUCT :: struct { dw_data: rawptr, size: u32, lp_data: rawptr }

Info_Response :: struct {
    xpos, ypos, width, height: i32,
    pitch, tilt, center, invView, subp, ri, bi: f32,
}

@private did_receive_calibration := false;
@private received_info : Info_Response;

my_window_proc :: proc "c" (hwnd: Hwnd, msg: u32, wparam: Wparam, lparam: Lparam) -> Lresult {
    if (msg == WM_COPYDATA) {
        fmt.println("ODIN GOT COPYDATA!", msg);

        cds := cast(^COPYDATASTRUCT)cast(uintptr)lparam;

        assert(cds.size == size_of(Info_Response));
        device_info := cast(^Info_Response)cds.lp_data;
        fmt.println("got device info", device_info);

        received_info = device_info^;
        did_receive_calibration = true;
    }

    return cast(Lresult)cast(uintptr)CallWindowProcW(orig_wnd_proc, hwnd, msg, wparam, lparam);
}

@private
hpc_init :: proc(my_hwnd: rawptr) -> (bool, Info_Response) {
    my_hwnd := cast(Hwnd)cast(uintptr)my_hwnd;
    orig_wnd_proc = cast(Wnd_Proc)cast(rawptr)cast(uintptr)set_window_long_ptr_w(my_hwnd, GWLP_WNDPROC, cast(win32.Long_Ptr)cast(uintptr)cast(rawptr)my_window_proc);

    driver_resource_hwnd := FindWindowW(utf8_to_wstring("GLFW30"), utf8_to_wstring("ResourceWindow"));
    Info_Request :: struct { foo: u32, };
    info_request := Info_Request { 42 };
    copydata := COPYDATASTRUCT { nil, size_of(Info_Request), &info_request };
    hwnd:Hwnd = cast(Hwnd)cast(uintptr)driver_resource_hwnd;
    fmt.println("sending WM_COPYDATA to", hwnd, "my hwnd is", my_hwnd);
    res := SendMessageW(hwnd, WM_COPYDATA, cast(Wparam)cast(uintptr)my_hwnd, cast(Lparam)cast(uintptr)&copydata);
    fmt.println("res is", res);
    return did_receive_calibration, received_info;
}