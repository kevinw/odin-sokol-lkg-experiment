package preprocess

import "core:os"
import "core:fmt"
import "core:mem"
import "core:odin/parser"
import "core:odin/ast"
import "core:strings"

main :: proc() {
    //
    // SHADER METAPROGRAMMING
    //
    {
        fullpath := "c:\\src\\game\\src\\shader_globals.odin";
        data, success := os.read_entire_file(fullpath);
        if !success {
            fmt.eprintln("error reading", fullpath);
            return;
        }

        pkg := ast.Package {
            kind = .Init,
            id = 0,
            name="main",
            fullpath="c:\\src\\game\\src",
            files={},
        };

        file := ast.File {
            id=0,
            pkg=&pkg,
            fullpath=fullpath,
            src=data,
        };

        p := parser.default_parser();
        res := parser.parse_file(&p, &file);
        if !res {
            fmt.eprintln("error parsing file", fullpath);
            return;
        }

        using ast;

        builder := strings.make_builder(context.temp_allocator);
        defer strings.destroy_builder(&builder);

        fmt.sbprintf(&builder, "// AUTOGENERATED\n\n");

        for decl in p.file.decls {
            ok: bool;

            d: Value_Decl;
            if d, ok = decl.derived.(Value_Decl); !ok {
                continue;
            }

            assert(len(d.names) == 1);
            ident := d.names[0].derived.(Ident);

            struct_type: Struct_Type;
            if struct_type, ok = d.type.derived.(Struct_Type); !ok {
                continue;
            }

            fmt.sbprintf(&builder, "uniform %s {\n", ident.name);

            for field in struct_type.fields.list {
                for name in field.names {
                    field_ident := name.derived.(Ident);
                    switch field_type in field.type.derived {
                        case Ident:
                            switch field_type.name {
                                case "f32":
                                    fmt.sbprintf(&builder, "    float %s;\n", field_ident.name);
                                case:
                                    fmt.eprintln("unknown", field_type.name);
                            }
                        case:
                            fmt.eprintln("unhandled field_type", field_type);
                    }
                }
            }

            fmt.sbprintf(&builder, "};\n");
        }

        s := strings.to_string(builder);
        //fmt.println(s);
        output_filename := "globals.glsl";
        os.write_entire_file(output_filename, mem.slice_ptr(&s[0], len(s)));
        fmt.println("wrote", output_filename);
    }

}
