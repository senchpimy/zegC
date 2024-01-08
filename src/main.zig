const std = @import("std");
const debug = std.debug;
const fs = std.fs;
const io = std.io;
const mem = std.mem;
const os = std.os;

const primitive_operations = [_][]const u8{ "+", "-", "*", "/", "%", "&&", "||", "!", "==", "!=", ">", "<", ">=", "<=", "&", "|", "^", "~", "<<", ">>" };
const Operation = enum { add, subs, mul, div, mod, and_o };

const primitive_types = [_][]const u8{ "int", "char", "long", "bool", "void", "double" };
const Type = enum { int, char, long, bool, void, double };

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
const DataType = enum { TypeDeclaration, String, Assignation };
const Instruction = struct { type: DataType, string: []u8, index: i16 };

const Variable = struct { type: Type, value: u8 };
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
            try os.tcsetattr(tty.handle, .FLUSH, original);
            os.exit(0);
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
    _ = isn;
}

fn create_instruction() !std.ArrayList(Instruction) {
    //std.heap.page_allocator);
    var list = std.ArrayList(Instruction).init(std.heap.page_allocator);
    var splits = std.mem.split(u8, buf[0 .. mb_index - 1], " ");
    var len: usize = 0;
    while (splits.next()) |_| {
        len += 1;
    }
    splits.reset();
    while (splits.next()) |str| {
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
        try list.append(Instruction{ .type = .String, .string = string, .index = -1 }); //Unesecary string
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
            v_type = .bool;
        },
        4 => {
            v_type = .void;
        },
        5 => {
            v_type = .double;
        },
        else => {
            //std.debug.print("\n '{s}' is not a type", .{first});
            //return ParsingError.Type;
        },
    }
}

fn cmp_type(str: []const u8, index: usize) bool {
    return std.mem.eql(u8, str, primitive_types[index]);
}
