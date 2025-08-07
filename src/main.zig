// main.zig
const std = @import("std");
const debug = std.debug;
const fs = std.fs;
const io = std.io;
const mem = std.mem;
const os = std.os;

const terminal = @import("terminal.zig");
const evaluate = @import("evaluate.zig");
const lexer = @import("lexer.zig");

const c = @cImport({
    @cInclude("termios.h");
});

pub const Variable = struct { type: lexer.Type, value: lexer.Payload }; //Repetition?

const stdout = std.io.getStdOut().writer();
pub var buf: [100]u8 = undefined;
var promt_v: terminal.Prompt = .start;
var variables = std.StringHashMap(Variable).init(std.heap.page_allocator);
pub var mb_index: u32 = 0; //main buffer index

pub fn main() !void {
    var init = terminal.initTerminal() catch |err| switch (err) {
        error.NoTty => {
            std.debug.print("No TTY available. Exiting.\n", .{});
            return;
        },
        else => |e| return e,
    };
    defer {
        init.tty.close();
    }

    while (true) {
        try terminal.prompt(&promt_v);
        var buffer: [1]u8 = undefined;
        _ = try init.tty.read(&buffer);
        const char = buffer[0];
        if (char == '\x1B') {
            _ = try init.tty.read(&buffer);
            _ = try init.tty.read(&buffer);
            if (buffer[0] == 'D') { // Izquierda
                std.debug.print("\x1B[D", .{});
            } else if (buffer[0] == 'C') { // Derecha
                std.debug.print("\x1B[C", .{});
            } else if (buffer[0] == 'A') {
                debug.print("Arriba\r\n", .{});
            } else if (buffer[0] == 'B') {
                debug.print("Abajo\r\n", .{});
            } else {
                debug.print("cahr {d}\r\n", .{buffer[0]});
            }
        } else if (char == 3) { // Ctrl+C
            break;
        } else if (std.ascii.isASCII(char)) {
            if (char == '\r') { // Enter
                if (mb_index > 0 and buf[mb_index - 1] == ';') {
                    parse_str() catch |err| {
                        try stdout.print("\nError: {any}\n", .{err});
                    };
                    promt_v = .start;
                    @memset(&buf, 0);
                    mb_index = 0;
                    try stdout.print("\n", .{});
                    continue;
                }
                promt_v = .cont;
                try terminal.prompt(&promt_v);
                continue;
            } else if (char == 0x7F or char == 0x08) { // Backspace (127 o 8)
                if (mb_index > 0) {
                    mb_index -= 1;
                    buf[mb_index] = 0;
                    try stdout.print("\x08 \x08", .{});
                }
            } else {
                if (mb_index < buf.len) {
                    get_string(mb_index, char);
                    try stdout.print("{c}", .{char});
                    mb_index += 1;
                }
            }
        } else {
            debug.print("novalue: {} {s}\r\n", .{ buffer[0], buffer });
        }
    }
    _ = os.linux.tcsetattr(init.tty.handle, .FLUSH, &init.termios);
    var iter = variables.iterator();
    debug.print("\n", .{});
    while (iter.next()) |key| {
        debug.print("VARIABLE {s} {any}\n", .{ key.key_ptr.*, key.value_ptr.* });
    }
}

fn get_string(index: u32, char: u8) void {
    buf[index] = char;
}

fn parse_str() !void {
    const instruction_list = try lexer.create_instruction(buf[0..mb_index]);
    defer {
        for (instruction_list.items) |item| {
            std.heap.page_allocator.free(item.string);
        }
        instruction_list.deinit();
    }

    const slice = instruction_list.items;
    if (slice.len == 0) return; // No hacer nada si la entrada está vacía (ej. ";")

    if (slice[0].type == .TypeDeclaration) {
        if (slice.len < 2) {
            return lexer.ParsingError.MissingVariableName;
        }
        if (slice.len > 3 and slice[2].type == .Assignation) {
            const new_var_type = lexer.match_type(slice[0].index);
            const f = try match_payload_value(new_var_type, slice[3]);
            const new_var = Variable{ .type = new_var_type, .value = f };
            try variables.put(slice[1].string, new_var);
            try stdout.print("\nVariable '{s}' creada con valor.", .{slice[1].string});
        } else {
            const t = lexer.match_type(slice[0].index);
            const p = lexer.match_payload(t);
            const v: Variable = Variable{ .type = t, .value = p };
            try variables.put(slice[1].string, v);
            try stdout.print("\nVariable '{s}' declarada.", .{slice[1].string});
        }
    }
}

fn match_payload_value(t: lexer.Type, v: lexer.Instruction) !lexer.Payload {
    std.debug.print("TYpe {any}\n", .{t});
    std.debug.print("Ins {any}\n", .{v});
    var p: lexer.Payload = undefined;
    if (v.type != .Value) {
        return lexer.ParsingError.InvalidValue;
    }

    switch (t) {
        .int => {
            p = lexer.Payload{ .int = undefined };
        },
        .char => {
            p = lexer.Payload{ .char = undefined };
        },
        .long => {
            p = lexer.Payload{ .long = undefined };
        },
        .boolean => {
            p = lexer.Payload{ .boolean = undefined };
        },
        .void => {
            p = lexer.Payload{ .void = undefined };
        },
        .double => {
            p = lexer.Payload{ .double = undefined };
        },
        .float => {
            p = lexer.Payload{ .float = undefined };
        },
    }

    switch (v.string[0]) {
        '\'' => { //char||[]char
            // Lógica para literales char
        },
        else => {
            if (std.ascii.isDigit(v.string[0])) { // Es un literal numérico
                switch (t) {
                    .int => p.int = try std.fmt.parseInt(i32, v.string, 10),
                    .char => return lexer.ParsingError.TypeMismatch,
                    .long => p.long = try std.fmt.parseInt(i64, v.string, 10),
                    .boolean => return lexer.ParsingError.TypeMismatch,
                    .double => p.double = try std.fmt.parseFloat(f64, v.string),
                    .float => p.float = try std.fmt.parseFloat(f32, v.string),
                    else => {},
                }
            } else { // Es un nombre de variable
                // --- LÓGICA RESTAURADA ---
                if (variables.contains(v.string)) { //Asignacion a variable
                    const tmp = variables.get(v.string).?;

                    // Para que funcione, hacemos una asignación simple si los tipos coinciden.
                    if (tmp.type == t) {
                        p = tmp.value;
                    } else {
                        // Aquí se mantiene el bloque comentado como andamio para el futuro casting de tipos.
                        //_ = tmp;
                        //switch (tmp.value) {
                        //    .int => |val| switch (t) {
                        //        .int => p.int = val,
                        //        .double => p.double = @as(f64, val),
                        //        else => {}, // handle any other types
                        //    },
                        //    .char => |val| switch (t) {
                        //        .char => p.char = val,
                        //        else => {}, // handle any other types
                        //    },
                        //    .long => |val| switch (t) {
                        //        .long => p.long = val,
                        //        .double => p.double = @as(f64, val),
                        //        else => {}, // handle any other types
                        //    },
                        //    .boolean => |val| switch (t) {
                        //        .boolean => p.boolean = val,
                        //        else => {}, // handle any other types
                        //    },
                        //    .double => |val| switch (t) {
                        //        .double => p.double = val,
                        //        .int => p.double = @as(i16, val),
                        //        .long => p.long = @as(i64, val),
                        //        else => {}, // handle any other types
                        //    },
                        //    .float => |val| switch (t) {
                        //        .float => p.float = val,
                        //        .int => p.float = @as(i32, val),
                        //        else => {}, // handle any other types
                        //    },
                        //    else => {}, // handle any other types
                        //}
                        return lexer.ParsingError.TypeMismatch; // Por ahora, si los tipos no coinciden, es un error.
                    }
                } else {
                    return lexer.ParsingError.UndefinedVariable;
                }
            }
        },
    }
    return p;
}
