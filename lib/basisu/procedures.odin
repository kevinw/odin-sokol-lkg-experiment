package basisu

import sg "sokol:sokol_gfx"

when ODIN_OS == "windows" do foreign import basisu_lib "basisu.lib"

@(default_calling_convention="c")
@(link_prefix="sbasisu_")
foreign basisu_lib {
    setup :: proc() ---
    shutdown :: proc() ---
    free :: proc(img_desc: ^sg.Image_Desc) ---
}

@(default_calling_convention="c")
foreign basisu_lib {
    sbasisu_transcode ::proc(bytes: ^u8, count: i32) -> sg.Image_Desc ---
}

transcode :: proc(bytes: []u8) -> sg.Image_Desc {
    return sbasisu_transcode(&bytes[0], cast(i32)len(bytes));
}
