package main

import mu "../lib/microui"
import "core:strings"
import "core:fmt"

DEFAULT_BUFFER_SIZE :: 200;

mu_label_printf :: proc(ctx: ^mu.Context, fmt_str: string, args: ..any) {
	data: [DEFAULT_BUFFER_SIZE]byte;
	buf := strings.builder_from_slice(data[:]);
	res := fmt.sbprintf(&buf, fmt_str, ..args);

    // @Speed: don't clone
    c_str := strings.clone_to_cstring(res);
    defer delete(c_str);

    mu.label(ctx, c_str);
}

mu_layout_row :: proc(ctx: ^mu.Context, items: i32, widths: []i32, height: i32) {
    widths_ptr := &widths[0];
    mu.layout_row(ctx, items, widths_ptr, height);
}
