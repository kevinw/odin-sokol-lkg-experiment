package socket_wip

using import "core:sys/win32"
foreign import "system:ws2_32.lib"

WSADESCRIPTION_LEN :: 256;
WSASYS_STATUS_LEN :: 128;
NO_ERROR :: 0;

FIONBIO :i32 = -2147195266;

WSA_Data :: struct {
    version: u16,
    high_version: u16,
    description: [WSADESCRIPTION_LEN + 1]u8,
    system_status: [WSASYS_STATUS_LEN + 1]u8,

    max_sockets: u16,
    max_udp_dg: u16,
    vendor_info: ^u8,
}; 

Socket :: distinct rawptr;

AF_INET :: 2;
SOCK_STREAM :: 1;
SOCK_DGRAM :: 2;

In_Addr :: struct #raw_union {
    addr: u32,
    using bytes: struct {
        b1, b2, b3, b4: u8,
    },
};

inet_addr :: proc(a, b, c, d: u8) -> In_Addr {
    res: In_Addr;
    res.b1 = a;
    res.b2 = b;
    res.b3 = c;
    res.b4 = d;
    return res;
}

Sock_Addr_In :: struct {
    family: i16,
    port: u16,
    addr: In_Addr,
    zero: [8]u8,
};

Sock_Addr :: struct {
    family: u16,
    data: [14]u8,
};

#assert(size_of(Sock_Addr) == size_of(Sock_Addr_In));

INADDR_ANY : In_Addr; // 0.0.0.0

@(default_calling_convention = "std")
foreign ws2_32 {
    @(link_name="WSAStartup") wsa_startup :: proc(version_required: u16, wsa_data: ^WSA_Data) -> i32 ---
    @(link_name="WSAGetLastError") wsa_get_last_error :: proc() -> i32 ---
    socket :: proc (af, type, protocol: i32) -> Socket ---
    htons :: proc(hostshort: u16) -> u16 ---
    bind :: proc(s: Socket, name: ^Sock_Addr, name_len: i32) -> i32 ---
    listen :: proc(s: Socket, backlog: i32) -> i32 ---
    accept :: proc(s: Socket, addr: ^Sock_Addr, addr_len: i32) -> Socket ---
    closesocket :: proc(socket: Socket) ---
    send :: proc(socket: Socket, buf: ^u8, len: i32, flags: i32) -> i32 ---
    ioctlsocket :: proc(socket: Socket, cmd: i32, arg: ^u32) -> i32 ---
    recvfrom :: proc(socket: Socket, buf: ^byte, len: i32, flags: i32, from: ^Sock_Addr, from_len: ^i32) -> i32 ---
}

make_word :: proc(low, high: u8) -> u16 do return cast(u16)(high << 8) | cast(u16)low;

SOCKET_ERROR:i32 = -1;
INVALID_SOCKET:Socket = cast(Socket)cast(uintptr)(0xffffffffffffffff);


/*
osc_main :: proc() {
    port:u16 = 10000;

    data : WSA_Data;
    if err := wsa_startup(make_word(2, 2), &data); err != 0 {
        fmt.eprintln("WSAStartup failed with error:", err);
        return;
    }

    server := socket(AF_INET, SOCK_STREAM, 0);

    i_mode:u32 = 1;
    if ioctlsocket(server, FIONBIO, &i_mode) != NO_ERROR {
        fmt.eprintln("could not set blocking mode");
        return;
    }

    addr := Sock_Addr_In {
        family = AF_INET,
        port = htons(port),
        addr = INADDR_ANY,
    };

    if err := bind(server, cast(^Sock_Addr)(&addr), size_of(addr)); err == SOCKET_ERROR {
        fmt.eprintln("could not bind server socket");
        return;
    }

    if err := listen(server, 30); err == SOCKET_ERROR {
        fmt.eprintln("error listening for a connection");
        return;
    }

    client_addr: Sock_Addr_In;
    count := 0;
    for {
        client := accept(server, cast(^Sock_Addr)(&client_addr), size_of(client_addr));
        if client == INVALID_SOCKET {
            fmt.println("no connection", client, count);
            count += 1;
            sleep(1000);
            continue;
        }

        fmt.println("got connection", client);

        hello_msg := "hello from the server!";
        send(client, &hello_msg[0], cast(i32)len(hello_msg), 0); 
        closesocket(client);
        break;
    }

    closesocket(server);
}
*/
