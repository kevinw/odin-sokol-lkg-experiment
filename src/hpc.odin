package main

import "core:fmt"

Display_Info :: struct {
    xpos, ypos, width, height: i32,
    pitch, tilt, center, invView, subp, ri, bi: f32,
}

// these are just the values from my personal looking glass (for
// testing!) -kevin
STOCK_DISPLAY_INFO := Display_Info {
    xpos = -2560,
    ypos = -154,
    width = 2560,
    height = 1600,
    pitch = 354.622,
    tilt = -0.114,
    center = -0.107,
    invView = 1.000,
    subp = 0,
    ri = 0,
    bi = 2,
};

MAX_DEVICES :: 10;
@private _hpc_state: struct {
    did_receive_calibration : bool,
    received_device_infos: [MAX_DEVICES]Display_Info,
    num_received_devices: i32,
};

import hpc "../lib/HoloPlayCore"

@private holoplaycore_init :: proc() -> (bool, []Display_Info) {
    using hpc;
    using _hpc_state;

    defer hpc.tear_down_message_pipe();

    {
        msg := hpc.Message {command = "{\"info\":{}}" };
        reply := hpc.send_message_blocking(&msg);
        if (reply.client_error != .NOERROR) {
            fmt.eprintln("hpc error:", reply.client_error);
            return false, nil;
        }

        if reply.num_devices < 1 {
            return false, nil;
        }
    }

    // TODO: select a device on the commandline?

    {
        msg := hpc.Message { command = "{\"uniforms\":{}}" };
        reply := hpc.send_message_blocking(&msg);
        if (reply.client_error != .NOERROR) {
            fmt.eprintln("hpc error:", reply.client_error);
        } else {
            // TODO: get rid of this Display_Info struct and just use the struct in HoloplayCore directly
            using reply.uniforms;
            num_received_devices = 1;
            received_device_infos[0] = Display_Info {
                xpos = win_x,
                ypos = win_y,
                width = win_w,
                height = win_h,
                pitch = pitch,
                tilt = tilt,
                center = center,
                invView = invView,
                subp = subp,
                ri = ri,
                bi = bi,
            };
            return true, received_device_infos[:1];
        }
    }

    return false, nil;
}

