@setlocal
@set PATH=c:\src\fips-deploy\sokol-tools\win64-vstudio-debug;%PATH%

set OPT_LEVEL=0
sokol-shdc --input vertcolor.glsl --output src/shader_meta/vertcolor.odin --slang hlsl5 && ^
sokol-shdc --input sdf_text.glsl --output src/shader_meta/sdf_text.odin --slang hlsl5 && ^
odin run src -collection=sokol=../odin-sokol/src -opt=%OPT_LEVEL% -debug -show-timings

