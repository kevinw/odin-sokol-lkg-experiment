@setlocal
set OUT_LIB=basisu.lib
cl /nologo /I"..\..\..\odin-sokol\src\sokol_gfx" /Z7 /O2 /c basisu_sokol.cpp basisu_transcoder.cpp && ^
lib /nologo *.obj /out:%OUTPUT_LIB% && ^
echo Built %OUT_LIB% && ^
del *.obj
