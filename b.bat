@echo off
setlocal
set PATH=c:\src\fips-deploy\sokol-tools\win64-vstudio-debug;%PATH%
set SHDC=sokol-shdc --slang hlsl5 --input
set OPT_LEVEL=0

preprocess.exe &&^
%SHDC% vertcolor.glsl --output src/shader_meta/vertcolor.odin && ^
%SHDC% sdf_text.glsl --output src/shader_meta/sdf_text.odin && ^
%SHDC% cgltf_sapp.glsl --output src/shader_meta/cgltf_sapp.odin && ^
odin run src -collection=sokol=../odin-sokol/src -opt=%OPT_LEVEL% -debug -show-timings

