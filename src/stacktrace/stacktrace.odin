/*
The MIT License

Copyright (c) 2019 Aleksander B. Birkeland

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
*/

package stacktrace

import "core:fmt"

when ODIN_OS == "windows" {
	import "core:sys/win32"
	foreign import "system:kernel32.lib"
	foreign import "system:Dbghelp.lib"

	Symbol_Info :: struct {
		SizeOfStruct: u32,
		TypeIndex:    u32,
		Reserved:     [2]u64,
		Index:        u32,
		Size:         u32,
		ModBase:      u64,
		Flags:        u32,
		Value:        u64,
		Address:      u64,
		Register:     u32,
		Scope:        u32,
		Tag:          u32,
		NameLen:      u32,
		MaxNameLen:   u32,
		Name:         [1]u8,
	}

	ImageHlp_Line64 :: struct {
		SizeOfStruct: u32,
		Key:          rawptr,
		LineNumber:   u32,
		FileName:     cstring,
		Address:      u64,
	}

	Sym_Option :: enum u32 {
		UNDNAME      = 0x00000002,
		LOAD_LINES   = 0x00000010,
		PUBLICS_ONLY = 0x00004000,
	}

	@(default_calling_convention = "std")
	foreign Dbghelp {
		@(link_name="SymInitialize")
		sym_initialize :: proc(process: win32.Handle, user_search_path: ^cstring, invade_process: win32.Bool) -> win32.Bool ---;

		@(link_name="SymCleanup")
		sym_cleanup :: proc(process: win32.Handle) -> win32.Bool ---;

		@(link_name="SymFromAddr")
		sym_from_addr :: proc(process: win32.Handle, address: u64, displacement: ^u64, symbol: ^Symbol_Info) -> win32.Bool ---;

		@(link_name="SymSetOptions")
		sym_set_options :: proc(sym_options: Sym_Option) -> u32 ---;

		@(link_name="SymGetLineFromAddr64")
		sym_get_line_from_addr_64 :: proc(process: win32.Handle, addr: u64, displacement: ^u32, line: ^ImageHlp_Line64) -> win32.Bool ---;
	}


	@(default_calling_convention = "std")
	foreign kernel32 {
		@(link_name="RtlCaptureStackBackTrace")
		capture_stack_back_trace :: proc(frames_to_skip: u32, frames_to_capture: u32, backtrace: ^rawptr, backtrace_hash: ^u32) -> u16 ---;

		@(link_name="GetCurrentProcess")
		get_current_process :: proc() -> win32.Handle ---;
	}

	print_stack_trace :: proc(skip_frames: u32 = 0, skip_this_proc := true) {
		process := get_current_process();
		sym_initialize(process, nil, true);
		sym_set_options(Sym_Option.PUBLICS_ONLY);

		stack: [100]rawptr;

		frames_to_skip := skip_this_proc ? 1+skip_frames : 0+skip_frames;
		num_captures := capture_stack_back_trace(frames_to_skip, 100, &stack[0], nil);
		captured_stack := stack[:num_captures];
		
		symbol_buffer: [size_of(Symbol_Info) + 256]u8;
		symbol := cast(^Symbol_Info) &symbol_buffer[0];
		symbol.MaxNameLen = 255;
		symbol.SizeOfStruct = size_of(Symbol_Info);

		line: ImageHlp_Line64;
		line.SizeOfStruct = size_of(ImageHlp_Line64);

		for v in captured_stack {
			sym_from_addr(process, u64(uintptr(v)), nil, symbol);
			dummy: u32 = 0;
			sym_get_line_from_addr_64(process, symbol.Address, &dummy, &line);
			fmt.printf("%v - %v:%v - %v\n", rawptr(uintptr(symbol.Address)), line.FileName, line.LineNumber, cstring(&symbol.Name[0]));
		}

		sym_cleanup(process);
	}
}
else when ODIN_OS == "linux" {
	import "core:mem"

	Dl_info :: struct {
		fname: cstring,
		fbase: rawptr,
		sname: cstring,
		saddr: rawptr,
	}

	Elf64_Sym :: struct {
		st_name: u32,
		st_info: u8,
		st_other: u8,
		st_shndx: u16,
		st_value: u64,
		st_size: u64,
	}

	foreign import dl "system:dl"
	foreign import libc "system:c"

	print_stack_trace :: proc(skip_frames: u32 = 0, skip_this_proc := true) {
		foreign libc {
			backtrace :: proc"c"(buffer: ^rawptr, size: i32) -> i32 ---;
			backtrace_symbols :: proc"c"(buffer: ^rawptr, size: i32) -> ^cstring ---;
		}

		RTLD_DL_SYMENT :: 1;
		RTLD_DL_LINKMAP :: 2;
		foreign dl {
			dladdr :: proc"c"(addr: rawptr, info: ^Dl_info) -> i32 ---;
			dladdr1 :: proc"c"(addr: rawptr, info: ^Dl_info, extra_info: ^rawptr, flags: i32) -> i32 ---;
		}

		all_addresses: [100]rawptr;
		total_frames := backtrace(&all_addresses[0], i32(len(all_addresses)));

		addresses := all_addresses[:total_frames];

		symbols_raw := backtrace_symbols(&addresses[0], i32(len(addresses)));
		defer os.unix_free(symbols_raw);

		symbols := mem.slice_ptr(symbols_raw, len(addresses));
		for v, i in symbols {
			str := cast(string) symbols[i];
			name_len := 0;
			for str[name_len] != '(' {
				name_len += 1;
			}
			name := str[:name_len];

			info: Dl_info;
			esym: Elf64_Sym;
			dladdr1(addresses[i], &info, cast(^rawptr) &esym, RTLD_DL_SYMENT);
			fmt.printf("esym: %v\n", esym);

			fmt.printf("%v - %v\n", addresses[i], v);
		}
	}
}

import "core:runtime"
import "core:os"
assertion_failure_with_stacktrace_proc :: proc(prefix, message: string, loc: runtime.Source_Code_Location) {
	fd := os.stderr;
	runtime.print_caller_location(fd, loc);
	os.write_string(fd, " ");
	os.write_string(fd, prefix);
	if len(message) > 0 {
		os.write_string(fd, ": ");
		os.write_string(fd, message);
	}
	os.write_byte(fd, '\n');
	print_stack_trace(1);
	runtime.debug_trap();
}

/*

test2 :: proc() {
	panic("What is this? A strack trace?!");
}

test :: proc() {
	test2();
}

main :: proc() {
	context.assertion_failure_proc = assertion_failure_with_stacktrace_proc;
	test();
}
*/
