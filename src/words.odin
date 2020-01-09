package main

import sgl "../lib/odin-sokol/src/sokol_gl"
import sapp "../lib/odin-sokol/src/sokol_app"

import "./math"
import "core:fmt"
import "core:os"
import "core:math/rand"
import "core:strings"

word_list: map[string]string;

None   :: struct {};
Wall   :: struct {};
Letter :: struct { char: byte };
Player :: struct {};

Cell :: union #no_nil {
    None, // default
    Wall,
    Letter,
    Player,
}

level: struct {
    w, h: i16,
    player: struct { pos: [2]i16 },
    grid: [dynamic]Cell,
};

grid_set :: inline proc(pos: [2]i16, cell: Cell) {
    level.grid[pos.y * level.w + pos.x] = cell;
}

grid_get :: inline proc(pos: [2]i16) -> Cell {
    return level.grid[pos.y * level.w + pos.x];
}

init_level :: proc() {
    using level;
    w, h = 8, 8;
    grid = make([dynamic]Cell, w * h); // @Leak

    // walls
    for y in 0..<h {
        for x in 0..<w {
            if x == 0 || x == w - 1 || y == 0 || y == h - 1 {
                grid_set([2]i16 {x, y}, Wall {});
            }
        }
    }

    // letters
    rng := rand.create(43);

    for y in 1..<h-1 {
        for x in 1..<w-1 {
            if rand.float32(&rng) < .2 {
                rand_letter := 'A' + cast(u8)(rand.float32(&rng) * 26.0);
                grid_set([2]i16 {x, y}, Letter { char = rand_letter });
            }
        }
    }

    // player
    {
        using level.player;
        pos = {5, 5};
        grid_set(pos, Player {});
    }
}

try_push :: proc(pos: [2]i16, delta: [2]i16) -> bool {
    using level;
    using player;

    new_pos := pos + delta;

    if new_pos.x >= w || new_pos.x < 0 do return false;
    if new_pos.y >= h || new_pos.y < 0 do return false;

    #partial switch v in grid[new_pos.y * w + new_pos.x] {
        case Wall, Player:
            return false;
        case Letter:
            fmt.println("trying to push Letter ", cast(rune)v.char);

            past := new_pos + delta;
            switch past_v in grid[past.y * w + past.x] {
                case Letter, Player, Wall:
                    fmt.println("...but cannot, it is blocked");
                    return false;
                case None:
                    fmt.println("...success! moving ", v, " into ", past);
                    grid_set(past, v);
            }
    }


    grid_set(pos, None {});
    inline for i in 0..1 do pos[i] = new_pos[i];
    grid_set(new_pos, Player {});

    return true;
}

check_for_words :: proc() {
    using level;

    letters := make([dynamic]Letter, context.temp_allocator);

    // check horizontal runs
    for y in 0..<h {
        min_index:i16 = -1;
        for x in 0..<w {
            v := grid_get([2]i16 {x, y});
            if letter, ok := v.(Letter); ok {
                if min_index == -1 do min_index = x;
                append(&letters, letter);
            } else {
                // TODO: check end (in case the last thing is a letter)
                if min_index != -1 {
                    check_letters(letters[:]);
                    clear(&letters);
                    min_index = -1;
                }
            }
        }
    }
}

check_letters :: proc(letters: []Letter) {
    builder := strings.make_builder(context.temp_allocator);
    for letter in letters {
        strings.write_byte(&builder, letter.char);
    }
    fmt.println(strings.to_string(builder));
}

update_level :: proc() {
    using level;
    {
        using player;

        delta: [2]i16;
        input_2d_pressed(&delta);

        if delta.x != 0 || delta.y != 0 {
            try_push(pos, delta);
            check_for_words();
        }
    }
}

_did_draw_text := false;

draw_level :: proc() {
    using level;

    tw, th :f32 = 40, 40;

    sgl.defaults();
    sgl.push_pipeline();
    defer sgl.pop_pipeline();
    sgl.viewport(0, 0, cast(i32)sapp.width(), cast(i32)sapp.height(), true);
    sgl.ortho(0, cast(f32)sapp.width(), cast(f32)sapp.height(), 0, -10, 10);
    vp := math.ortho3d(0, cast(f32)sapp.width(), cast(f32)sapp.height(), 0, -10, 10);
    defer sgl.draw();

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
            is_letter := false;
            switch v in cell {
                case None:
                    empty = true;
                case Wall:
                    r, g, b = 255, 0, 0;
                    debug_char = "*";
                case Letter:
                    r, g, b = 128, 128, 128;
                    strings.reset_builder(&builder);
                    strings.write_byte(&builder, v.char);
                    debug_char = strings.to_string(builder);
                    is_letter = true;
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
                if is_letter {
                    gamma := editor_settings.sdftext.gamma;
                    layer_buf := editor_settings.sdftext.buf;
                    draw_text(true, debug_char, th, math.Vector3 { xf * tw, yf * th, -0.1 }, gamma, layer_buf);
                }
            }
        }

        if !_did_draw_text {
            fmt.printf("\n");
        }
    }

    {
        //BEGIN_PASS(text.pass, text.pass_action);
        num_views := 1;
        color := math.Vector4 { 1, 1, 1, 1 };
        sdf_text_render(vp, math.identity(Matrix4), num_views, color);
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
