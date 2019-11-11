package microui

import "core:c"

when ODIN_OS == "windows" do foreign import libmicroui "./microui.lib";

// Has to match constants compiled microui.h
VERSION :: "1.02";
COMMANDLIST_SIZE    :: (1024 * 256);
ROOTLIST_SIZE       :: 32;
CONTAINERSTACK_SIZE :: 32;
CLIPSTACK_SIZE      :: 32;
IDSTACK_SIZE        :: 32;
LAYOUTSTACK_SIZE    :: 16;
MAX_WIDTHS          :: 16;
REAL                :: c.float;
REAL_FMT            :: "%.3g";
SLIDER_FMT          :: "%.02f";
MAX_FMT             :: 127;

UNCLIPPED_RECT := Rect{ 0, 0, 0x1000000, 0x1000000 };

Clip :: enum c.int {
	None,
	Part,
	All,
}

Command_Type :: enum c.int {
	Jump = 1,
	Clip,
	Rect,
	Text,
	Icon,
    DrawCallback,
	Max,
}

Style_Color :: enum c.int {
	Text,
	Border,
	WindowBG,
	TitleBG,
	TitleText,
	PanelBG,
	Button,
	ButtonHover,
	ButtonFocus,
	Base,
	BaseHover,
	BaseFocus,
	ScrollBase,
	ScrollThumb,
	Max,
}

Icon :: enum c.int {
	Close = 1,
	Check,
	Collapsed,
	Expanded,
	Max,
}

//TODO: Some of the '-> b32' procs like slider should actually return Res, or maybe just c.int
Res :: enum c.int {
	Active       = (1 << 0),
	Submit       = (1 << 1),
	Change       = (1 << 2),
}

Opt :: enum c.int {
	AlignCenter,
	AlignRight,
	NoInteract,
	NoFrame,
	NoResize,
	NoScroll,
	NoClose,
	NoTitle,
	HoldFocus,
	AutoSize,
	Popup,
	Closed,
}
Opt_Set :: bit_set[Opt; c.int];

Mouse :: enum c.int {
	Left       = (1 << 0),
	Right      = (1 << 1),
	Middle     = (1 << 2),
}

Key :: enum c.int {
	Shift        = (1 << 0),
	Ctrl         = (1 << 1),
	Alt          = (1 << 2),
	Backspace    = (1 << 3),
	Return       = (1 << 4),
}

Stack :: struct(T: typeid, N: int) {
	idx: c.int,
	items: [N]T,
}

Id :: c.uint;
Real :: REAL;
Font :: rawptr;

Vec2  :: struct { x, y: c.int }
Rect  :: struct { x, y, w, h: c.int }
Color :: struct { r, g, b, a: u8 }

BaseCommand :: struct { type: Command_Type, size: c.int }
JumpCommand :: struct { base: BaseCommand, dst: rawptr }
ClipCommand :: struct { base: BaseCommand, rect: Rect, }
RectCommand :: struct { base: BaseCommand, rect: Rect, color: Color }
//FIXME: Find a better way to bind VLAs in Odin
TextCommand :: struct { base: BaseCommand, font: Font, pos: Vec2, color: Color, str: [1]u8 }
IconCommand :: struct { base: BaseCommand, rect: Rect, id: c.int, color: Color }
DrawCallbackCommand :: struct { base: BaseCommand, rect: Rect, callback: rawptr }

Command :: struct #raw_union {
	type: Command_Type,
	base: BaseCommand,
	jump: JumpCommand,
	clip: ClipCommand,
	rect: RectCommand,
	text: TextCommand,
	icon: IconCommand,
    draw_callback: DrawCallbackCommand,
}

Layout :: struct {
	body      : Rect,
	next      : Rect,
	position  : Vec2,
	size      : Vec2,
	max       : Vec2,
	widths    : [MAX_WIDTHS]c.int,
	items     : c.int,
	row_index : c.int,
	next_row  : c.int,
	next_type : c.int,
	indent    : c.int,
}

Container :: struct {
	head, tail   : ^Command,
	rect         : Rect,
	body         : Rect,
	content_size : Vec2,
	scroll       : Vec2,
	inited       : c.int,
	zindex       : c.int,
	open         : c.int,
}

Style :: struct {
	font           : Font,
	size           : Vec2,
	padding        : c.int,
	spacing        : c.int,
	indent         : c.int,
	title_height   : c.int,
	scrollbar_size : c.int,
	thumb_size     : c.int,
	colors         : [Style_Color.Max]Color,
}

Context :: struct {
	/* callbacks */
	text_width      : proc"c"(font: Font, str: cstring, len: c.int) -> c.int,
	text_height     : proc"c"(font: Font) -> c.int,
	draw_frame      : proc"c"(ctx: ^Context, rect: Rect, colorid: c.int),
	/* core state */
	_style          : Style,
	style           : ^Style,
	hover           : Id,
	focus           : Id,
	last_id         : Id,
	last_rect       : Rect,
	last_zindex     : c.int,
	updated_focus   : c.int,
	hover_root      : ^Container,
	last_hover_root : ^Container,
	scroll_target   : ^Container,
	number_buf      : [MAX_FMT]u8,
	number_editing  : Id,
	/* stacks */
	command_list    : Stack(u8, COMMANDLIST_SIZE),
	root_list       : Stack(^Container, ROOTLIST_SIZE),
	container_stack : Stack(^Container, CONTAINERSTACK_SIZE),
	clip_stack      : Stack(Rect, CLIPSTACK_SIZE),
	id_stack        : Stack(Id, IDSTACK_SIZE),
	layout_stack    : Stack(Layout, LAYOUTSTACK_SIZE),
	/* input state */
	mouse_pos       : Vec2,
	last_mouse_pos  : Vec2,
	mouse_delta     : Vec2,
	scroll_delta    : Vec2,
	mouse_down      : c.int,
	mouse_pressed   : c.int,
	key_down        : c.int,
	key_pressed     : c.int,
	text_input      : [32]u8,
};


@(default_calling_convention="c", link_prefix="mu_")
foreign libmicroui {
	vec2  :: proc(x: c.int, y: c.int) -> Vec2                      ---;
	rect  :: proc(x: c.int, y: c.int, w: c.int, h: c.int) -> Rect  ---;
	color :: proc(r: c.int, g: c.int, b: c.int, a: c.int) -> Color ---;

	init           :: proc(ctx: ^Context)                                  ---;
	begin          :: proc(ctx: ^Context)                                  ---;
	end            :: proc(ctx: ^Context)                                  ---;
	set_focus      :: proc(ctx: ^Context, id: Id)                          ---;
	get_id         :: proc(ctx: ^Context, data: rawptr, size: c.int) -> Id ---;
	push_id        :: proc(ctx: ^Context, data: rawptr, size: c.int)       ---;
	push_id_ptr    :: proc(ctx: ^Context, data: rawptr)                    ---;
	pop_id         :: proc(ctx: ^Context)                                  ---;
	push_clip_rect :: proc(ctx: ^Context, rect: Rect)                      ---;
	pop_clip_rect  :: proc(ctx: ^Context)                                  ---;
	get_clip_rect  :: proc(ctx: ^Context) -> Rect                          ---;
	check_clip     :: proc(ctx: ^Context, r: Rect) -> b32                  ---;
	get_container  :: proc(ctx: ^Context) -> ^Container                    ---;
	init_window    :: proc(ctx: ^Context, cnt: ^Container, opt: Opt_Set)   ---;
	bring_to_front :: proc(ctx: ^Context, cnt: ^Container)                 ---;

	input_mousemove :: proc(ctx: ^Context, x, y: c.int)             ---;
	input_mousedown :: proc(ctx: ^Context, x, y: c.int, btn: c.int) ---;
	input_mouseup   :: proc(ctx: ^Context, x, y: c.int, btn: c.int) ---;
	input_scroll    :: proc(ctx: ^Context, x, y: c.int)             ---;
	input_keydown   :: proc(ctx: ^Context, key: c.int)              ---;
	input_keyup     :: proc(ctx: ^Context, key: c.int)              ---;
	input_text      :: proc(ctx: ^Context, text: cstring)           ---;

	push_command :: proc(ctx: ^Context, type: c.int, size: c.int) -> ^Command                          ---;
	next_command :: proc(ctx: ^Context, cmd: ^^Command) -> b32                                         ---;
	set_clip     :: proc(ctx: ^Context, rect: Rect)                                                    ---;
	draw_rect    :: proc(ctx: ^Context, rect: Rect, color: Color)                                      ---;
	draw_callback:: proc(ctx: ^Context, rect: Rect, cb: rawptr)                                      ---;
	draw_box     :: proc(ctx: ^Context, rect: Rect, color: Color)                                      ---;
	draw_text    :: proc(ctx: ^Context, font: Font, str: cstring, len: c.int, pos: Vec2, color: Color) ---;
	draw_icon    :: proc(ctx: ^Context, id: c.int, rect: Rect, color: Color)                           ---;

	layout_row          :: proc(ctx: ^Context, items: c.int, widths: ^c.int, height: c.int) ---;
	layout_width        :: proc(ctx: ^Context, width: c.int)                                ---;
	layout_height       :: proc(ctx: ^Context, height: c.int)                               ---;
	layout_begin_column :: proc(ctx: ^Context)                                              ---;
	layout_end_column   :: proc(ctx: ^Context)                                              ---;
	layout_set_next     :: proc(ctx: ^Context, r: Rect, relative: c.int)                    ---;
	layout_next         :: proc(ctx: ^Context) -> Rect                                      ---;

	draw_control_frame :: proc(ctx: ^Context, id: Id, rect: Rect, colorid: c.int, opt: Opt_Set)       ---;
	draw_control_text  :: proc(ctx: ^Context, str: cstring, rect: Rect, colorid: c.int, opt: Opt_Set) ---;
	mouse_over         :: proc(ctx: ^Context, rect: Rect) -> b32                                      ---;
	update_control     :: proc(ctx: ^Context, id: Id, rect: Rect, opt: Opt_Set)                       ---;

	text            :: proc(ctx: ^Context, text: cstring)                                                                      ---;
	label           :: proc(ctx: ^Context, text: cstring)                                                                      ---;
	button_ex       :: proc(ctx: ^Context, label: cstring, icon: c.int, opt: Opt_Set) -> b32                                   ---;
	button          :: proc(ctx: ^Context, label: cstring) -> b32                                                              ---;
	checkbox        :: proc(ctx: ^Context, state: ^c.int, label: cstring) -> b32                                               ---;
	textbox_raw     :: proc(ctx: ^Context, buf: ^u8, bufsz: c.int, id: Id, r: Rect, opt: Opt_Set) -> b32                       ---;
	textbox_ex      :: proc(ctx: ^Context, buf: ^u8, bufsz: c.int, opt: Opt_Set) -> b32                                        ---;
	textbox         :: proc(ctx: ^Context, buf: ^u8, bufsz: c.int) -> b32                                                      ---;
	slider_ex       :: proc(ctx: ^Context, value: ^Real, low: Real, high: Real, step: Real, fmt: cstring, opt: Opt_Set) -> Res ---;
	slider          :: proc(ctx: ^Context, value: ^Real, low: Real, high: Real) -> Res                                         ---;
	number_ex       :: proc(ctx: ^Context, value: ^Real, step: Real, fmt: cstring, opt: Opt_Set) -> b32                        ---;
	number          :: proc(ctx: ^Context, value: ^Real, step: Real) -> b32                                                    ---;
	header          :: proc(ctx: ^Context, state: ^c.int, label: cstring) -> b32                                               ---;
	begin_treenode  :: proc(ctx: ^Context, state: ^c.int, label: cstring) -> b32                                               ---;
	end_treenode    :: proc(ctx: ^Context)                                                                                     ---;
	begin_window_ex :: proc(ctx: ^Context, cnt: ^Container, title: cstring, opt: Opt_Set) -> b32                               ---;
	begin_window    :: proc(ctx: ^Context, cnt: ^Container, title: cstring) -> b32                                             ---;
	end_window      :: proc(ctx: ^Context)                                                                                     ---;
	open_popup      :: proc(ctx: ^Context, cnt: ^Container)                                                                    ---;
	begin_popup     :: proc(ctx: ^Context, cnt: ^Container) -> b32                                                             ---;
	end_popup       :: proc(ctx: ^Context)                                                                                     ---;
	begin_panel_ex  :: proc(ctx: ^Context, cnt: ^Container, opt: Opt_Set)                                                      ---;
	begin_panel     :: proc(ctx: ^Context, cnt: ^Container)                                                                    ---;
	end_panel       :: proc(ctx: ^Context)                                                                                     ---;
}

#assert(size_of(Vec2) == 8)
#assert(size_of(Rect) == 16)
#assert(size_of(Color) == 4)

#assert(size_of(BaseCommand) == 8)
#assert(size_of(JumpCommand) == 16)
#assert(size_of(ClipCommand) == 24)
#assert(size_of(RectCommand) == 28)
#assert(size_of(TextCommand) == 32)
#assert(size_of(IconCommand) == 32)

#assert(size_of(Command) == 32)
#assert(size_of(Layout) == 140)
#assert(size_of(Container) == 80)
#assert(size_of(Style) == 96)
#assert(size_of(Context) == 265976)

/*
#include <stdio.h>
int main() {
    printf("Context: %lu\n", sizeof(mu_Context));
    printf("Style: %lu\n", sizeof(mu_Style));
    printf("Container: %lu\n", sizeof(mu_Container));
    printf("Layout: %lu\n", sizeof(mu_Layout));
    printf("Command: %lu\n", sizeof(mu_Command));
    printf("BaseCommand: %lu\n", sizeof(mu_BaseCommand));
    printf("JumpCommand: %lu\n", sizeof(mu_JumpCommand));
    printf("ClipCommand: %lu\n", sizeof(mu_ClipCommand));
    printf("RectCommand: %lu\n", sizeof(mu_RectCommand));
    printf("TextCommand: %lu\n", sizeof(mu_TextCommand));
    printf("IconCommand: %lu\n", sizeof(mu_IconCommand));
    printf("Vec2: %lu\n", sizeof(mu_Vec2));
    printf("Rect: %lu\n", sizeof(mu_Rect));
    printf("Color: %lu\n", sizeof(mu_Color));
}
*/
