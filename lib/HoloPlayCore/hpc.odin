package hpc

when ODIN_OS == "windows" {
    foreign import HoloPlayCore {
        "./HoloPlayCore.lib",
        "./nng.lib",
        "system:ws2_32.lib",
        "system:mswsock.lib",
        "system:advapi32.lib",
    }
}

Raw_Calibration :: struct {
    serial: cstring,
    pitch: f64,
    slope: f64,
    center: f64,
    screen_w: f64,
    screen_h: f64,
    inv_view: f64,
    flip_image_x: f64,
    flip_image_y: f64,
    flip_subp: f64,
    dpi: f64,
    view_cone: f64,
    cal_version: i32,
    // lkgName will only be defined if calVersion >= 2!
    // this indicates that the calibration / HDMI names have been matched
    // by the calibration updater tool 
    lkg_name: cstring,
};

Uniforms :: struct {
    win_x: i32,
    win_y: i32,
    win_w: i32,
    win_h: i32,
    invView: f32,
    subp: f32,
    ri: f32,
    bi: f32,
    pitch: f32,
    center: f32,
    tilt: f32,
};

// Error code returned from libHoloPlayCore.dll
// (i.e., we did not get a roundtrip message/response for some reason)
Client_Error :: enum i32 {
    NOERROR,
    NOSERVICE,
    SERIALIZEERR,
    VERSIONERR,
    PIPEERROR,
    TIMEDOUT
};

// Error code returned from Holoplay Service.
// (we got a response, but it contains an error flag)
Service_Error :: enum i32 {
    NOERROR,
    BADCBOR,
    BADCOMMAND,
    NOIMAGE,
    LKGNOTFOUND,
    NOTINCACHE,
    INITTOOLATE,
    NOTALLOWED,
};

Looking_Glass :: struct {
    index: i32,
    x_pos: i32,
    y_pos: i32,
    state: cstring,
    hwid: cstring,
    hardwareVersion: cstring,
    windowCoords: [2]i32,
    calibration: Raw_Calibration,
    uniforms: Uniforms,
};

// The Reply struct describes every possible top-level value that might
// be returned from the service.
Reply :: struct {
    service_error: Service_Error,
    client_error: Client_Error,
    version: cstring,
    fragment: cstring,
    vertex: cstring,
    devices: ^Looking_Glass,
    uniforms: ^Uniforms,
    num_devices: i32,
};

Message :: struct {
    command: cstring,
    bin: ^u8,
    binlen: uint,
};

@(default_calling_convention="c", link_prefix="hpc_")
foreign HoloPlayCore {
    @(link_name="hpc_SendMessageBlocking")
    send_message_blocking :: proc(message: ^Message) -> Reply ---

    @(link_name="hpc_TeardownMessagePipe")
    tear_down_message_pipe :: proc() ---
}

/*
    msg := hpc.Message {command = "{\"info\":{}}" };
    reply := hpc.send_message_blocking(&msg);
    if (reply.client_error != .NOERROR) {
        fmt.eprintln("hpc error:", reply.client_error);
    } else {
        fmt.printf("HoloPlay Service version: %s\n", reply.version);
        fmt.printf("%d Looking Glass device%s present.\n", reply.num_devices, (reply.num_devices == 1 ? "" : "s"));

        devices := mem.slice_ptr(reply.devices, cast(int)reply.num_devices);
        for device in devices {
            fmt.printf("Device %d:\n", device.index);
            fmt.printf("\tHardware version: %s\n", device.hardwareVersion);
            fmt.printf("\tState: %s\n", device.state);
            fmt.printf("\tHDMI name: %s\n", device.hwid);

            device_state := string(device.state);
            if strings.contains(device_state, "hidden") || strings.contains(device_state, "ok") {
            //if (strstr(r.devices[i].state, "hidden") || strstr(r.devices[i].state, "ok"))
                fmt.printf("\tSerial: %s\n", device.calibration.serial);
                fmt.printf("\tWindow coordinates: (%d, %d)\n", device.x_pos, device.y_pos);
            }
        }
        hpc.tear_down_message_pipe();
    }
 */
