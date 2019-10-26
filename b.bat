@setlocal
@set PATH=%PATH%;c:\Users\Kevin\src\fips-deploy\sokol-tools\win64-vstudio-release

cls && ^
sokol-shdc --input vertcolor.glsl --output src/shader_meta/vertcolor.odin --slang hlsl5 && ^
odin run src/main.odin -collection=sokol=../odin-sokol/src
