package termcolor

import "core:fmt"
using import "core:sys/win32";

Coord :: struct { x, y: i16 }

Small_Rect :: struct { left, top, right, bottom: i16 }

Console_Screen_Buffer_Info :: struct {
    size: Coord,
    cursor_position: Coord,
    attributes: u16,
    window: Small_Rect,
    maximum_window_size: Coord,
};

Foreground :: enum u16 {
    Unset = 0,
    Blue = 0x0001,
    Green = 0x0002,
    Red = 0x0004,
    Intensity = 0x0008,
}

Background :: enum u16 {
    Unset = 0,
    Blue = 0x0010,
    Green = 0x0020,
    Red = 0x0040,
    Intensity = 0x0080,
}

foreign import "system:kernel32.lib"
@(default_calling_convention = "std")
foreign kernel32 {
    @(link_name="SetConsoleTextAttribute") set_console_text_attribute :: proc(
        console_output: Handle, attributes: u16) -> Bool ---

    @(link_name="GetConsoleScreenBufferInfo") get_console_screen_buffer_info :: proc(
        console_output: Handle, console_screen_buffer_info: ^Console_Screen_Buffer_Info) -> Bool ---
}

PUSH_COLOR :: proc(foreground: Foreground, background: Background) -> u16 {
    console := get_std_handle(STD_OUTPUT_HANDLE);
    get_console_screen_buffer_info(console, 
}
