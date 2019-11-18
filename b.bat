@echo off
setlocal
set PATH=c:\src\fips-deploy\sokol-tools\win64-vstudio-release;%PATH%
set SHDC=sokol-shdc --slang hlsl5 --input
set OPT_LEVEL=0

set OUT_DIR=src/shader_meta

preprocess.exe &&^
echo Compiling shaders... &&^
%SHDC% gizmos.glsl --output %OUT_DIR%/gizmos.odin && ^
%SHDC% shadertoy.glsl --output %OUT_DIR%/shadertoy.odin && ^
%SHDC% sdf_text.glsl --output %OUT_DIR%/sdf_text.odin && ^
%SHDC% cgltf_sapp.glsl --output %OUT_DIR%/cgltf_sapp.odin && ^
%SHDC% mrt_sapp.glsl --output %OUT_DIR%/mrt_sapp.odin && ^
echo Building game... &&^
odin build src -collection=sokol=../odin-sokol/src -opt=%OPT_LEVEL% -debug -ignore-unknown-attributes

REM -show-timings -keep-temp-files 
