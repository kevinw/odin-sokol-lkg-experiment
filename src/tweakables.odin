
// THIS FILE WAS AUTOGENERATED
package main

Tweakable :: struct {
    name: string,
    ptr: proc() -> any,
};

all_tweakables := [?]Tweakable {
    { "editor_settings", proc() -> any { return editor_settings; } },
};
