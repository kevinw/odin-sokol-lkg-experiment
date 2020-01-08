package main

import sgl "../lib/odin-sokol/src/sokol_gl"

import "core:fmt"
import "core:os"
import "core:math/rand"
import "core:strings"

word_list: map[string]string;

None :: struct {};
Wall :: struct {};
Letter :: struct { char: byte };
Player :: struct {};

Cell :: union {
    None,
    Wall,
    Letter,
    Player,
}

level: struct {
    w, h: u16,
    grid: [dynamic]Cell,
};

init_level :: proc() {
    using level;
    w, h = 8, 8;
    grid = make([dynamic]Cell, w * h); // @Leak
    for _, i in grid {
        grid[i] = None {};
    }

    // walls
    for y in 0..<h {
        for x in 0..<w {
            if x == 0 || x == w - 1 || y == 0 || y == h - 1 {
                grid[y * w + x] = Wall {};
            }
        }
    }

    // letters
    rng := rand.create(43);

    for y in 1..<h-1 {
        for x in 1..<w-1 {
            if rand.float32(&rng) < .2 {
                rand_letter := 'A' + cast(u8)(rand.float32(&rng) * 26.0);
                grid[y * w + x] = Letter { char = rand_letter };
            }
        }
    }

    // player
    {
        x, y:u16 = 5, 5;
        grid[y * w + x] = Player {};
    }
}

_did_draw_text := false;

draw_level :: proc() {
    using level;

    tw, th :f32 = 40, 40;

    sgl.begin_quads();
    defer sgl.end();

    builder := strings.make_builder();
    defer strings.destroy_builder(&builder);

    for y in 0..<h {
        for x in 0..<w {
            cell := grid[x + y * w];
            r, g, b: u8;
            debug_char := " ";
            empty := false;
            switch v in cell {
                case None:
                    empty = true;
                case Wall:
                    r, g, b = 255, 0, 0;
                    debug_char = "*";
                case Letter:
                    r, g, b = 255, 255, 255;
                    //draw_text(txt, y, v3(f32(0), y, z), gamma, layer_buf);
                    strings.reset_builder(&builder);
                    strings.write_byte(&builder, v.char);
                    debug_char = strings.to_string(builder);
                case Player:
                    r, g, b = 0, 0, 255;
                    debug_char = "@";
            }

            if !_did_draw_text {
                fmt.printf("%s", debug_char);
            }

            if !empty {
                xf, yf := f32(x), f32(y);

                sgl.c3b(r, g, b);
                sgl.v2f(xf * tw, yf * th);
                sgl.v2f(xf * tw + tw, yf * th);
                sgl.v2f(xf * tw + tw, yf * th + th);
                sgl.v2f(xf * tw, yf * th + th);
            }
        }

        if !_did_draw_text {
            fmt.printf("\n");
        }
    }

    _did_draw_text = true;
}

load_word_list :: proc() {
    bytes, ok := os.read_entire_file("resources/scrabble-words.txt");
    if !ok do panic("could not load word list");
    str := strings.string_from_ptr(&bytes[0], len(bytes));

    lines := strings.split(str, "\n", context.temp_allocator);
    for line, i in lines {
        if len(line) < 2 do continue;

        tab_index := strings.index_byte(line, '\t');
        assert(tab_index > 0, fmt.tprint("no tab character found on line ", i));
        word := line[0:tab_index];
        rest := line[tab_index + 1:];
        word_list[word] = rest;
    }
}
