package basisu

when ODIN_OS == "windows" do foreign import basisu_lib "basisu.lib"

@(default_calling_convention="c")
@(link_prefix="sbasisu_")
foreign basisu_lib {
    setup :: proc() ---
    shutdown :: proc() ---
}
