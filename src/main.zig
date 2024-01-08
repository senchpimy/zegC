const std = @import("std");
const debug = std.debug;
const fs = std.fs;
const io = std.io;
const mem = std.mem;
const os = std.os;

const primitive_types = [_][]const u8{ "int", "char", "long", "bool", "void", "double" };
const Type = enum { int, char, long, bool, void, double };
const Prompt = enum { start, none, cont };
const ParsingError = error{Type};

const Variable = struct { type: Type, value: u8 };
const stdout = std.io.getStdOut().writer();
//const stdin = std.io.getStdIn();
var buf: [100]u8 = undefined;
var promt_v: Prompt = .start;
//var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
var variables = std.StringHashMap(Variable).init(std.heap.page_allocator);

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
    var index: u32 = 0;
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
                if (buf[index - 1] == ';') {
                    parse_str(&buf) catch |err| switch (err) {
                        else => {},
                    };
                    promt_v = .start;
                    @memset(&buf, 0);
                    index = 0;
                    try stdout.print("\n", .{});
                    continue;
                }
                promt_v = .cont;
                try prompt();
                continue;
            }
            get_string(index, char);
            debug.print("{c}", .{char});
            index += 1;
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

fn parse_str(str: []u8) !void {
    _ = str;
    var splits = std.mem.split(u8, buf[0..], " ");
    var len: usize = 0;
    while (splits.next()) |_| {
        len += 1;
    }
    splits.reset();
    if (len == 2) { //variable creation but no assignation
        var first = splits.next().?;
        var v_type: Type = undefined;
        var type_index: i16 = 0;
        for (primitive_types) |typ| {
            if (std.mem.eql(u8, first, typ)) {
                break;
            }
            type_index += 1;
        } else {
            type_index = -1;
        }
        switch (type_index) {
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
                std.debug.print("\n '{s}' is not a type", .{first});
                return ParsingError.Type;
            },
        }
        var v: Variable = Variable{ .type = v_type, .value = undefined };
        try variables.put(splits.next().?, v);
        std.debug.print("{any}", .{v});
    }
}

fn cmp_type(str: []const u8, index: usize) bool {
    return std.mem.eql(u8, str, primitive_types[index]);
}
