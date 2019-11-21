package tosc

Message :: struct {
    format: ^byte, // a pointer to the format field
    marker: ^byte, // the current read head
    buffer: ^byte, // the original message data (also points to the address)
    len: u32,      // length of the buffer data
};


Bundle :: struct {
    marker: ^u8,    // the current write head (where the next message will be written)
    buffer: ^u8,    // the original buffer
    bufLen: u32,    // the byte length of the original buffer
    bundleLen: u32, // the byte length of the total bundle
};

when ODIN_OS == "windows" {
    foreign import tosc_lib "tinyosc.lib"
}

@(default_calling_convention = "c")
@(link_prefix="tosc_")
foreign tosc_lib {
    @(link_name="tosc_isBundle")
    is_bundle :: proc(buffer: ^u8) -> bool ---
    @(link_name="tosc_parseBundle")
    parse_bundle :: proc(b: ^Bundle, buffer: ^u8, len: i32) ---

    @(link_name="tosc_getTimetag")
    get_timetag :: proc(b: ^Bundle) -> u64 ---

    @(link_name="tosc_getNextMessage")
    get_next_message :: proc(b: ^Bundle, messsage: ^Message) -> bool ---

    @(link_name="tosc_printMessage")
    print_message :: proc(message: ^Message) ---

    @(link_name="tosc_parseMessage")
    parse_message :: proc(message: ^Message, buffer: ^byte, len: i32) -> i32 ---

    @(link_name="tosc_printOscBuffer")
    print_osc_buffer :: proc(buffer: ^byte, len: i32) ---
}

