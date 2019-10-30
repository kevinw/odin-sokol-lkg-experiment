@echo off
setlocal

cl /nologo /O2 /Z7 /c cgltf.c && lib /nologo cgltf.obj /OUT:cgltf.lib && del cgltf.obj && echo Built cgltf.lib
