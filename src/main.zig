const std = @import("std");
const debug = std.debug;
const fs = std.fs;
const io = std.io;
const mem = std.mem;
const os = std.os;
const terminal = @import("terminal.zig");
const evaluate = @import("evaluate.zig");
const c = @cImport({
    @cInclude("termios.h");
});
pub const Payload = union(Type) { int: i32, char: u8, long: i64, boolean: bool, void: u8, double: f64, float: f32 };

const primitive_operations = [_][]const u8{ "+", "-", "*", "/", "%", "&&", "||", "!", "==", "!=", ">", "<", ">=", "<=", "&", "|", "^", "~", "<<", ">>" };
const Operation = enum { add, subs, mul, div, mod, and_ };

pub const primitive_types = [_][]const u8{ "int", "char", "long", "bool", "void", "double", "float" };
pub const Type = enum { int, char, long, boolean, void, double, float };

const keywords = [_][]const u8{ "if", "else", "for", "while", "do", "struct" };
const Keywords = enum { if_, else_, for_, while_, do, struct_ };

const asignation_operations = [_][]const u8{ "=", "+=", "-=", "*=", "/=", "%=", "&=", "|=", "<<=", ">>=" };
const Assig = enum {
    basic,
    add,
    subs,
    mul,
    div,
    mod,
    and_o,
    or_o,
    xor,
    l_shf,
    r_shf,
};

const ParsingError = error{Type};
pub const DataType = enum { TypeDeclaration, Assignation, Value, Operation, Keywords };
pub const Instruction = struct { type: DataType, string: []u8, index: i16 };

pub const Variable = struct { type: Type, value: Payload }; //Repetition?
const stdout = std.io.getStdOut().writer();
//const stdin = std.io.getStdIn();
pub var buf: [100]u8 = undefined;
var promt_v: terminal.Prompt = .start;
//var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
var variables = std.StringHashMap(Variable).init(std.heap.page_allocator);
pub var mb_index: u32 = 0; //main buffer index

pub fn main() !void {
    var init = terminal.initTerminal() catch |err| switch (err) {
        error.NoTty => {
            // Handle the case where there is no TTY
            // For example, you could read from stdin
            // and print to stdout without terminal-specific features.
            // For now, we'll just exit gracefully.
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
                    parse_str() catch |err| switch (err) {
                        else => {},
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
                    buf[mb_index] = 0; // Limpiar posición
                    // Mover cursor izquierda, borrar carácter, mantener posición
                    try stdout.print("\x08 \x08", .{});
                }
            } else { // Carácter normal
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
    const isn = try create_instruction();
    const slice = isn.items;
    const len = slice.len;
    if (slice[0].type == .TypeDeclaration) {
        if (len > 2) { //More than one variable declaration or declaration and assignation
            switch (slice[2].type) {
                .Assignation => {
                    const new_var_type = match_type(slice[0].index);
                    const f = try match_payload_value(new_var_type, slice[3]);
                    const new_var = Variable{ .type = new_var_type, .value = f };
                    try variables.put(slice[1].string, new_var);
                },
                else => {},
            }

            try stdout.print("\n{any}", .{slice});
        } else { //Justa a single virable declaration
            evaluate.tes();
            const t = match_type(slice[0].index); //Index of type
            const p = match_payload(t);
            const v: Variable = Variable{ .type = t, .value = p };
            try variables.put(slice[1].string, v);
            try stdout.print("\nCreated variable! {any}", .{v});
        }
    }
}

pub fn create_instruction() !std.ArrayList(Instruction) {
    //std.heap.page_allocator);
    var list = std.ArrayList(Instruction).init(std.heap.page_allocator); //Create struct for multiple lines
    var instructions = std.mem.tokenizeScalar(u8, buf[0..mb_index], ';');
    while (instructions.next()) |intrs| {
        var splits = std.mem.splitScalar(u8, intrs, ' '); //Dont be dependent on spaces
        var len: usize = 0;
        while (splits.next()) |_| {
            len += 1;
        }
        splits.reset();
        while (splits.next()) |str| {
            if (str.len == 0) {
                continue;
            }
            var stri = std.ArrayList(u8).init(std.heap.page_allocator);
            try stri.resize(str.len);
            @memcpy(stri.items, str);
            const string = try stri.toOwnedSlice();
            var type_index: i16 = 0;
            var next = false;
            for (primitive_types) |typ| {
                if (std.mem.eql(u8, string, typ)) {
                    try list.append(Instruction{ .type = .TypeDeclaration, .string = string, .index = type_index }); //Unesecary string
                    next = true;
                    break;
                }
                type_index += 1;
            } else {
                type_index = 0;
            }
            //Not a type
            for (asignation_operations) |typ| {
                if (std.mem.eql(u8, string, typ)) {
                    try list.append(Instruction{ .type = .Assignation, .string = string, .index = type_index }); //Unesecary string
                    next = true;
                    break;
                }
                type_index += 1;
            } else {
                type_index = 0;
            }
            //Not a assignation
            //debug.print("No assignation ", args: anytype)
            //Then is a value/variable
            // check for while, for, if, switch, funct and other
            for (keywords) |kw| {
                if (std.mem.eql(u8, string, kw)) {
                    try list.append(Instruction{ .type = .Keywords, .string = string, .index = type_index }); //Unesecary string
                    next = true;
                    debug.print("Keyword {s}", .{string});
                    break;
                }
            }

            if (next) {
                continue;
            }
            try list.append(Instruction{ .type = .Value, .string = string, .index = -1 }); //Unesecary string
        }
    }
    return list;
}

pub fn match_type(index: i16) Type {
    var v_type: Type = undefined;
    switch (index) {
        0 => {
            v_type = .int;
        },
        1 => {
            v_type = .char;
        },
        2 => {
            v_type = .long;
        },
        3 => {
            v_type = .boolean;
        },
        4 => {
            v_type = .void;
        },
        5 => {
            v_type = .double;
        },
        6 => {
            v_type = .float;
        },
        else => {
            //std.debug.print("\n '{s}' is not a type", .{first});
            //return ParsingError.Type;
        },
    }
    return v_type;
}

fn cmp_type(str: []const u8, index: usize) bool {
    return std.mem.eql(u8, str, primitive_types[index]);
}

pub fn match_payload(t: Type) Payload {
    var p: Payload = undefined;
    switch (t) {
        .int => {
            p = Payload{ .int = undefined };
        },
        .char => {
            p = Payload{ .char = undefined };
        },
        .long => {
            p = Payload{ .long = undefined };
        },
        .boolean => {
            p = Payload{ .boolean = undefined };
        },
        .void => {
            p = Payload{ .void = undefined };
        },
        .double => {
            p = Payload{ .double = undefined };
        },
        .float => {
            p = Payload{ .float = undefined };
        },
    }
    return p;
}

pub fn match_payload_value(t: Type, v: Instruction) !Payload {
    std.debug.print("TYpe {any}\n", .{t});
    std.debug.print("Ins {any}\n", .{v});
    var p: Payload = undefined;
    if (v.type != .Value) {
        return p;
    }
    switch (t) {
        .int => {
            p = Payload{ .int = undefined };
        },
        .char => {
            p = Payload{ .char = undefined };
        },
        .long => {
            p = Payload{ .long = undefined };
        },
        .boolean => {
            p = Payload{ .boolean = undefined };
        },
        .void => {
            p = Payload{ .void = undefined };
        },
        .double => {
            p = Payload{ .double = undefined };
        },
        .float => {
            p = Payload{ .float = undefined };
        },
    }

    switch (v.string[0]) {
        //'\'' or '"' => { //char||[]char
        '\'' => { //char||[]char

        },
        else => {
            if (std.ascii.isDigit(v.string[0])) {
                switch (t) {
                    .int => {
                        p.int = try std.fmt.parseInt(i32, v.string, 10);
                    },
                    .char => {},
                    .long => {
                        p.int = try std.fmt.parseInt(i32, v.string, 10);
                    },
                    .boolean => {},
                    .double => {},
                    .float => {},
                    else => {}, // handle any other types
                }
            } else {
                if (variables.contains(v.string)) { //Asignacion a variable
                    const tmp = variables.get(v.string).?;
                    _ = tmp;
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
                }
            }
        },
    }

    return p;
}
