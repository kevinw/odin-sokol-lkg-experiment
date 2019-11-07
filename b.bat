@echo off
setlocal
set PATH=c:\src\fips-deploy\sokol-tools\win64-vstudio-debug;%PATH%
set SHDC=sokol-shdc --slang hlsl5 --input
set OPT_LEVEL=3

preprocess.exe &&^
%SHDC% shadertoy.glsl --output src/shader_meta/shadertoy.odin && ^
%SHDC% sdf_text.glsl --output src/shader_meta/sdf_text.odin && ^
%SHDC% cgltf_sapp.glsl --output src/shader_meta/cgltf_sapp.odin && ^
odin build src -collection=sokol=../odin-sokol/src -opt=%OPT_LEVEL% -show-timings -keep-temp-files 
