package main

import "core:fmt"
import "../math"
import "core:log"

import socket "../socket_wip"
import tosc "../../lib/tinyosc"

port :: 8005;

Socket :: socket.Socket;

s: Socket = socket.INVALID_SOCKET;

Callbacks :: struct {
    on_vector2 : proc(name: string, val: math.Vector2),
    on_vector3 : proc(name: string, val: math.Vector3),
    on_bool : proc(name: string, val: bool),
};

_cbs : Callbacks;

init :: proc(cbs: Callbacks) {
    using socket;

    _cbs = cbs;
    data : WSA_Data;
    if err := wsa_startup(make_word(2, 2), &data); err != 0 {
        log.fatal("WSAStartup failed with error:", err);
        return;
    }

    s = socket(AF_INET, SOCK_DGRAM, 0);
    if s == INVALID_SOCKET {
        log.error("could not initialize osc udp server");
        return;
    }

    server := Sock_Addr_In {
        family = AF_INET,
        addr = INADDR_ANY,
        port = htons(port),
    };

    log.info("osc server listening on port", port);
    if err := bind(s, cast(^Sock_Addr)(&server), size_of(server)); err == SOCKET_ERROR {
        log.error("could not bind server socket");
        return;
    }
}

buf : [1024*3]u8;
BUFLEN := i32(len(buf));
buffer := &buf[0];

strlen :: proc(s: ^$T) -> int { // TODO: doesn't this already exist?
    i := 0;
    for {
        val := mem.ptr_offset(s, i);
        if val^ == 0 do break;
        i += 1;
    }
    return i;
}

handle_message :: proc(message: ^tosc.Message) {
    using tosc;
    address := string(get_address(message));
    format := string(get_format(message));
    switch format {
        case "ff":
            if _cbs.on_vector2 != nil {
                _cbs.on_vector2(address, math.Vec2{get_next_f32(message), get_next_f32(message)});
            }
        case "fff":
            if _cbs.on_vector3 != nil {
                _cbs.on_vector3(address, math.Vec3{get_next_f32(message), get_next_f32(message), get_next_f32(message)});
            }
        case:
            fmt.println("unhandled format", format);
    }
}

update :: proc() {
    using socket;

    if s == INVALID_SOCKET do return;
		
    // try to receive some data, this is a blocking call
    si_other : Sock_Addr_In;
    sa_len := cast(i32)size_of(Sock_Addr);
    len := recvfrom(s, &buf[0], BUFLEN, i32(0), cast(^Sock_Addr)&si_other, &sa_len);
    if len == SOCKET_ERROR {
        fmt.println("recvfrom() failed with error code :", wsa_get_last_error());
        return;
    }

    osc: tosc.Message;
    if tosc.is_bundle(buffer) {
        bundle: tosc.Bundle;
        tosc.parse_bundle(&bundle, buffer, len);
        //timetag := tosc.get_timetag(&bundle);
        for tosc.get_next_message(&bundle, &osc) {
            handle_message(&osc);
        }
    } else {
        tosc.parse_message(&osc, buffer, len);
        //tosc.print_message(&osc);
        handle_message(&osc);
    }
}

shutdown :: proc() {
    if s == socket.INVALID_SOCKET do return;
    socket.closesocket(s);
    //wsa_cleanup();
}


/*
import "../../lib/dyad"

port :: 8000;

on_data :: proc "c" (e: ^dyad.Event) {
    fmt.println("on_data", e);
}

echo_message := cstring("Echo server\r\n");

on_accept :: proc "c" (e: ^dyad.Event) {
    fmt.println("did accept!", e);

    dyad.add_listener(e.remote, dyad.Event_Type.DATA, on_data, nil);
    dyad.writef(e.remote, echo_message);
}

on_error :: proc "c" (e: ^dyad.Event) {
    fmt.eprintln("server error:", e);
}

init :: proc() {
    dyad.init();
    serv := dyad.new_stream();
    dyad.add_listener(serv, dyad.Event_Type.ACCEPT, on_accept, nil);
    dyad.add_listener(serv, dyad.Event_Type.ERROR, on_error, nil);
    fmt.println("listening on port", port);
    dyad.listen(serv, port);
}

update :: proc() {
    dyad.update();
}

shutdown :: proc() {
    dyad.shutdown();
}

*/
