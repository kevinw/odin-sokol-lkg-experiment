package main

import "core:fmt"
using import "core:sys/win32"
import "core:strings";
import "core:os"

subprocess :: proc(format := "", args: ..any) -> bool {
    cmd := fmt.tprintf(format, ..args);
    ccmd := strings.clone_to_cstring(cmd);
    defer delete(ccmd);

    si := win32.Startup_Info {
        cb          = size_of(win32.Startup_Info),
        //flags       = win32.STARTF_USESTDHANDLES | win32.STARTF_USESHOWWINDOW,
        //show_window = win32.SW_SHOW,
        //stdin       = win32.get_std_handle(win32.STD_INPUT_HANDLE),
        //stdout      = win32.get_std_handle(win32.STD_OUTPUT_HANDLE),
        //stderr      = win32.get_std_handle(win32.STD_ERROR_HANDLE),
        //stdin = win32.Handle(os.stdin),
        //stdout = win32.Handle(os.stdout),
        //stderr = win32.Handle(os.stderr),
    };

    pi: win32.Process_Information;

    exit_code: u32;

    if win32.create_process_a(nil, ccmd, nil, nil, false, 0, nil, nil, &si, &pi) {
        win32.wait_for_single_object(pi.process, win32.INFINITE);
        win32.get_exit_code_process(pi.process, &exit_code);
        win32.close_handle(pi.process);
        win32.close_handle(pi.thread);
    } else {
        // failed to execute
        exit_code = ~u32(0);
    }

    return exit_code == 0;
}

