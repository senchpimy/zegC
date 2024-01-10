const std = @import("std");
const debug = std.debug;
const fs = std.fs;
const io = std.io;
const mem = std.mem;
const os = std.os;

const Payload = union(Type) { int: i32, char: u8, long: i64, boolean: bool, void: u8, double: f64, float: f32 };

const primitive_operations = [_][]const u8{ "+", "-", "*", "/", "%", "&&", "||", "!", "==", "!=", ">", "<", ">=", "<=", "&", "|", "^", "~", "<<", ">>" };
const Operation = enum { add, subs, mul, div, mod, and_o };

const primitive_types = [_][]const u8{ "int", "char", "long", "bool", "void", "double", "float" };
const Type = enum { int, char, long, boolean, void, double, float };

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

const Prompt = enum { start, none, cont };
const ParsingError = error{Type};
const DataType = enum { TypeDeclaration, Assignation, Value, Operation };
const Instruction = struct { type: DataType, string: []u8, index: i16 };

const Variable = struct { type: Type, value: Payload }; //Repetition?
const stdout = std.io.getStdOut().writer();
//const stdin = std.io.getStdIn();
var buf: [100]u8 = undefined;
var promt_v: Prompt = .start;
//var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
var variables = std.StringHashMap(Variable).init(std.heap.page_allocator);
var mb_index: u32 = 0; //main buffer index

pub fn main() !void {
    //defer arena.deinit();
    //try variables.put("st", Variable{ .type = .int, .value = 9 });
    var tty = try fs.cwd().openFile("/dev/tty", fs.File.OpenFlags{ .mode = .read_write });
    defer tty.close();

    const original = try os.tcgetattr(tty.handle);
    var raw = original;
    raw.lflag &= ~@as(
        os.linux.tcflag_t,
        os.linux.ECHO | os.linux.ICANON | os.linux.ISIG | os.linux.IEXTEN,
    );
    raw.iflag &= ~@as(
        os.linux.tcflag_t,
        os.linux.IXON | os.linux.ICRNL | os.linux.BRKINT | os.linux.INPCK | os.linux.ISTRIP,
    );
    raw.cc[os.system.V.TIME] = 0;
    raw.cc[os.system.V.MIN] = 1;
    try os.tcsetattr(tty.handle, .FLUSH, raw);
    while (true) {
        try prompt();
        var buffer: [1]u8 = undefined;
        _ = try tty.read(&buffer);
        var char = buffer[0];
        if (char == '\x1B') {
            _ = try tty.read(&buffer);
            _ = try tty.read(&buffer);
            if (buffer[0] == 'D') { //izq
                std.debug.print("\x1B[D", .{});
            } else if (buffer[0] == 'C') { //der
                std.debug.print("\x1B[C", .{});
            } else if (buffer[0] == 'A') {
                debug.print("Arriba\r\n", .{});
            } else if (buffer[0] == 'B') {
                debug.print("Abajo\r\n", .{});
            } else {
                //Handle esc
                debug.print("cahr {d}\r\n", .{buffer[0]});
            }
            //\033[6;3H
            //
            //debug.print("input: escape\r\n", .{});
        } else if (char == 3) {
            break;
            //try os.tcsetattr(tty.handle, .FLUSH, original);
            //os.exit(0);
        } else if (std.ascii.isASCII(char)) {
            if (char == '\r') {
                if (buf[mb_index - 1] == ';') {
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
                try prompt();
                continue;
            }
            get_string(mb_index, char);
            debug.print("{c}", .{char});
            mb_index += 1;
        } else {
            debug.print("novalue: {} {s}\r\n", .{ buffer[0], buffer });
        }
    }
    try os.tcsetattr(tty.handle, .FLUSH, original);
    var iter = variables.iterator();
    debug.print("\n", .{});
    while (iter.next()) |key| {
        debug.print("VARIABLE {s} {any}\n", .{ key.key_ptr.*, key.value_ptr.* });
    }
}

fn prompt() !void {
    switch (promt_v) {
        .start => {
            try stdout.print(">>>", .{});
            promt_v = Prompt.none;
        },
        .cont => {
            try stdout.print("\n...", .{});
            promt_v = Prompt.none;
        },
        else => {},
    }
}

fn get_string(index: u32, char: u8) void {
    buf[index] = char;
}

fn parse_str() !void {
    var isn = try create_instruction();
    var slice = isn.items;
    var len = slice.len;
    if (slice[0].type == .TypeDeclaration) {
        if (len > 2) { //More than one variable declaration or declaration and assignation
            switch (slice[2].type) {
                .Assignation => {
                    var new_var_type = match_type(slice[0].index);
                    var f = try match_payload_value(new_var_type, slice[3]);
                    var new_var = Variable{ .type = new_var_type, .value = f };
                    try variables.put(slice[1].string, new_var);
                },
                else => {},
            }

            try stdout.print("\n{any}", .{slice});
        } else { //Justa a single virable declaration
            var t = match_type(slice[0].index); //Index of type
            var p = match_payload(t);
            var v: Variable = Variable{ .type = t, .value = p };
            try variables.put(slice[1].string, v);
            try stdout.print("\nCreated variable! {any}", .{v});
        }
    }
}

fn create_instruction() !std.ArrayList(Instruction) {
    //std.heap.page_allocator);
    var list = std.ArrayList(Instruction).init(std.heap.page_allocator); //Create struct for multiple lines
    var instructions = std.mem.tokenizeScalar(u8, buf[0..mb_index], ';');
    while (instructions.next()) |intrs| {
        var splits = std.mem.split(u8, intrs, " "); //Dont be dependent on spaces
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
            var string = try stri.toOwnedSlice();
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
            //Then is a value/variable
            // check for while, for, if, switch, funct and other
            if (next) {
                continue;
            }
            try list.append(Instruction{ .type = .Value, .string = string, .index = -1 }); //Unesecary string
        }
    }
    return list;
}

fn match_type(index: i16) Type {
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

fn match_payload(t: Type) Payload {
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

fn match_payload_value(t: Type, v: Instruction) !Payload {
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
                    var tmp = variables.get(v.string).?;
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
