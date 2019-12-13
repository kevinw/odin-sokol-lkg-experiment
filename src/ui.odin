package main
import simgui "../lib/odin-sokol/src/sokol_imgui"
import imgui "../lib/odin-imgui"
import sapp "sokol:sokol_app"
import sg "sokol:sokol_gfx"

setup_simgui :: proc() {
    simgui.setup({
        //no_default_font = true,
        dpi_scale = sapp.dpi_scale(),
    });

    /*
    // TODO: this stuff is waiting on an odin bug to be fixed
    io := imgui.get_io();

    // configure Dear ImGui with our own embedded font
    font_cfg : imgui.FontConfig;
    imgui.font_config_default_constructor(&font_cfg);
    font_cfg.font_data_owned_by_atlas = false;
    font_cfg.oversample_h = 2;
    font_cfg.oversample_v = 2;
    font_cfg.rasterizer_multiply = 1.5;

    imgui.font_atlas_add_font_from_memory_ttf(io.fonts, &dump_font[0], size_of(dump_font), 16, &font_cfg);

    // create font texture for the custom font
    font_pixels: ^u8;
    font_width, font_height: i32;

    imgui.font_atlas_get_text_data_as_rgba32(io.fonts, &font_pixels, &font_width, &font_height);

    img_desc := sg.Image_Desc {
        width = font_width,
        height = font_height,
        pixel_format = .RGBA8,
        wrap_u = .CLAMP_TO_EDGE,
        wrap_v = .CLAMP_TO_EDGE,
        min_filter = .LINEAR,
        mag_filter = .LINEAR,
    };

    img_desc.content.subimage[0][0].ptr = font_pixels;
    img_desc.content.subimage[0][0].size = font_width * font_height * 4;

    io.fonts.tex_id = cast(imgui.TextureID)cast(uintptr)sg.make_image(img_desc).id;
    */
}
