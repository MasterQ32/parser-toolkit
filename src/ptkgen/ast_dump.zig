const std = @import("std");
const ptk = @import("parser-toolkit");

const ast = @import("ast.zig");
const parser = @import("parser.zig");

pub fn dump(strings: *const ptk.strings.Pool, decls: parser.Document) void {
    var printer = AstPrinter{
        .strings = strings,
    };

    printer.dumpRoot(decls.top_level_declarations);
}

const AstPrinter = struct {
    const print = std.debug.print;

    strings: *const ptk.strings.Pool,

    fn dumpRoot(printer: AstPrinter, decls: ast.List(ast.TopLevelDeclaration)) void {
        print("ast dump:\n", .{});

        var iter = ast.iterate(decls);
        while (iter.next()) |decl| {
            switch (decl) {
                .start => |item| print("start <{}>;\n", .{printer.fmtId(item.identifier)}),

                .rule => |rule| {
                    print("rule {s}", .{printer.fmtId(rule.name.value)});

                    if (rule.ast_type) |ast_type| {
                        print(" : ", .{});
                        printer.dumpAstType(ast_type);
                    }

                    print(" = \n", .{});

                    var prods = ast.iterate(rule.productions);
                    var first = true;
                    while (prods.next()) |prod| {
                        defer first = false;
                        if (!first) {
                            print("\n  | ", .{});
                        } else {
                            print("    ", .{});
                        }
                        printer.dumpMappedProd(prod);
                    }

                    print("\n;\n", .{});
                },

                .node => |node| {
                    print("node {s}", .{printer.fmtId(node.name.value)});
                    print(";\n", .{});
                },

                .token => |token| {
                    print("token {s}", .{printer.fmtId(token.name.value)});
                    print(";\n", .{});
                },
            }
        }
    }

    fn dumpAstType(printer: AstPrinter, typespec: ast.TypeSpec) void {
        _ = printer;
        _ = typespec;
        print("<TYPE HERE>", .{});
    }

    fn dumpMappedProd(printer: AstPrinter, mapped_prod: ast.MappedProduction) void {
        printer.dumpProd(mapped_prod.production);

        if (mapped_prod.mapping) |mapping| {
            print(" => ", .{});
            printer.dumpMapping(mapping);
        }
    }

    fn dumpProd(printer: AstPrinter, production: ast.Production) void {
        switch (production) {
            .literal => |lit| print("\"{}\"", .{printer.fmtString(lit.value)}),
            .terminal => |term| print("${}", .{printer.fmtId(term.identifier)}),
            .recursion => |term| print("<{}>", .{printer.fmtId(term.identifier)}),

            .sequence, .optional, .repetition_zero, .repetition_one => |seq| {
                print("(", .{});

                var iter = ast.iterate(seq);
                while (iter.next()) |item| {
                    print(" ", .{});
                    printer.dumpProd(item);
                }

                print(" )", .{});
                switch (production) {
                    .sequence => {},
                    .optional => print("?", .{}),
                    .repetition_zero => print("*", .{}),
                    .repetition_one => print("+", .{}),
                    else => unreachable,
                }
            },
        }
    }

    fn dumpMapping(printer: AstPrinter, mapping: ast.AstMapping) void {
        switch (mapping) {
            .record => |record| {
                _ = record;
                @panic("printing not implemented yet");
            },

            .list => |list| {
                if (list.len() > 0) {
                    print("{{ ", .{});
                    printer.dumpMappingList(list);
                    print(" }}", .{});
                } else {
                    print("{{}}", .{});
                }
            },

            .variant => |variant| {
                print("{}: ", .{printer.fmtId(variant.field.value)});
                printer.dumpMapping(variant.value.*);
            },

            .literal => |literal| print("`{s}`", .{printer.strings.get(literal.value)}),

            .context_reference => |context_reference| print("${}", .{context_reference.index}),

            .user_reference => |user_reference| print("@{}", .{printer.fmtId(user_reference.value)}),

            .user_function_call => |user_function_call| {
                print("@{}(", .{printer.fmtId(user_function_call.function.value)});
                printer.dumpMappingList(user_function_call.arguments);
                print(")", .{});
            },

            .function_call => |function_call| {
                print("{}(", .{printer.fmtId(function_call.function.value)});
                printer.dumpMappingList(function_call.arguments);
                print(")", .{});
            },
        }
    }

    fn dumpMappingList(printer: AstPrinter, list: ast.List(ast.AstMapping)) void {
        var first = true;
        var iter = ast.iterate(list);
        while (iter.next()) |arg| {
            if (!first) {
                print(", ", .{});
            }
            first = false;

            printer.dumpMapping(arg);
        }
    }

    fn fmtString(printer: AstPrinter, str: ptk.strings.String) StringPrinter {
        return StringPrinter{ .printer = printer, .str = str, .mode = .text };
    }

    fn fmtId(printer: AstPrinter, str: ptk.strings.String) StringPrinter {
        return StringPrinter{ .printer = printer, .str = str, .mode = .id };
    }

    const StringPrinter = struct {
        printer: AstPrinter,
        str: ptk.strings.String,
        mode: enum { id, text },

        pub fn format(strpr: StringPrinter, fmt: []const u8, opt: std.fmt.FormatOptions, writer: anytype) !void {
            _ = opt;
            _ = fmt;

            const text = strpr.printer.strings.get(strpr.str);
            switch (strpr.mode) {
                .id => try writer.print("{}", .{std.zig.fmtId(text)}),
                .text => try writer.print("{}", .{std.zig.fmtEscapes(text)}),
            }
        }
    };
};
