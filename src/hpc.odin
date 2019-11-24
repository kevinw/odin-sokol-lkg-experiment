package main

import "core:fmt"
import "core:mem"
using import "core:sys/win32"

@private orig_wnd_proc: Wnd_Proc;

Request :: struct { bytes: [4]u8, size_of_response: u32, };

Request_Type :: enum i32 { GetDevices, };
Response_Type :: enum i32 { Devices, };

Display_Info :: struct {
    xpos, ypos, width, height: i32,
    pitch, tilt, center, invView, subp, ri, bi: f32,
}

@private did_receive_calibration := false;
MAX_DEVICES :: 10;
@private received_device_infos : [MAX_DEVICES]Display_Info;
@private num_received_devices: i32;

my_window_proc :: proc "c" (hwnd: Hwnd, msg: u32, wparam: Wparam, lparam: Lparam) -> Lresult {
    if (msg == WM_COPYDATA) {
        copy_data := cast(^COPYDATASTRUCT)cast(uintptr)lparam;
        response_type := cast(Response_Type)cast(uintptr)copy_data.dw_data;
        if response_type == .Devices {
            assert(copy_data.size >= size_of(i32));
            num_received_devices = (cast(^i32)copy_data.lp_data)^;

            ptr_to_first_device := mem.ptr_offset(cast(^u8)copy_data.lp_data, size_of(i32));
            n := min(MAX_DEVICES, num_received_devices);
            devices := mem.slice_ptr(cast(^Display_Info)ptr_to_first_device, cast(int)n);
            for i in 0..<n do received_device_infos[i] = devices[i];

            did_receive_calibration = true;
            return 0;
        }
    }

    return cast(Lresult)cast(uintptr)CallWindowProcW(orig_wnd_proc, hwnd, msg, wparam, lparam);
}

@private
hpc_init :: proc(my_hwnd: rawptr) -> (bool, []Display_Info) {
    my_hwnd := cast(Hwnd)cast(uintptr)my_hwnd;

    // Add a new win32 message processing function.
    new_proc := cast(win32.Long_Ptr)cast(uintptr)cast(rawptr)my_window_proc;
    orig_wnd_proc = cast(Wnd_Proc)cast(rawptr)cast(uintptr)set_window_long_ptr_w(my_hwnd, GWLP_WNDPROC, new_proc);

    // Find the LKG driver resource window.
    driver_resource_hwnd := FindWindowW(utf8_to_wstring("GLFW30"), utf8_to_wstring("ResourceWindow"));

    if driver_resource_hwnd != nil {
        request := Request { {'L', 'K', 'G', '1'}, size_of(Display_Info) };
        copydata := COPYDATASTRUCT { nil, size_of(Request), &request };
        hwnd:Hwnd = cast(Hwnd)cast(uintptr)driver_resource_hwnd;
        SendMessageW(hwnd, WM_COPYDATA, cast(Wparam)cast(uintptr)my_hwnd, cast(Lparam)cast(uintptr)&copydata);
    }

    return did_receive_calibration, received_device_infos[:num_received_devices];
}