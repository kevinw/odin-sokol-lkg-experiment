@setlocal
@set PATH=c:\src\fips-deploy\sokol-tools\win64-vstudio-debug;%PATH%

cls && ^
sokol-shdc --input vertcolor.glsl --output src/shader_meta/vertcolor.odin --slang hlsl5 && ^
sokol-shdc --input sdf_text.glsl --output src/shader_meta/sdf_text.odin --slang hlsl5 && ^
odin run src/main.odin -collection=sokol=../odin-sokol/src
