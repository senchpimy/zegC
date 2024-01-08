const std = @import("std");
const debug = std.debug;
const fs = std.fs;
const io = std.io;
const mem = std.mem;
const os = std.os;

var types = [_][]const u8{ "int", "char", "long", "bool", "void" };
const Type = enum { int, char };
const Prompt = enum { start, none, cont };

const Variable = struct { type: Type, value: u8 };
const stdout = std.io.getStdOut().writer();
//const stdin = std.io.getStdIn();
var buf: [100]u8 = undefined;
var promt_v: Prompt = .start;

pub fn main() !void {
    @memset(&buf, 0);
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
            //_ = try tty.read(&buffer);
            //_ = try tty.read(&buffer);
            //if (buffer[0] == 'D') {
            //    debug.print("Izquierda\r\n", .{});
            //} else if (buffer[0] == 'C') {
            //    debug.print("Derecha\r\n", .{});
            //} else if (buffer[0] == 'A') {
            //    debug.print("Arriba\r\n", .{});
            //} else if (buffer[0] == 'B') {
            //    debug.print("Abajo\r\n", .{});
            //} else {
            //    //Handle esc
            //    debug.print("cahr {d}\r\n", .{buffer[0]});
            //}
            //debug.print("input: escape\r\n", .{});
        } else if (char == 3) { //Ctrl+c
            try os.tcsetattr(tty.handle, .FLUSH, original);
            os.exit(0);
        } else if (std.ascii.isASCII(char)) {
            if (char == '\n') {
                //if (buf[index] == ';') {
                //    @memset(&buf, 0);
                //    debug.print("\r\n", .{});
                //    continue;
                //}
                //debug.print("char {d}", .{buf[0]});
                promt_v = .cont;
                try prompt();
                try stdout.print("test", .{});
                continue;
            }
            _ = get_string(index, char);
            try stdout.print("{c}", .{char});
            index += 1;
        } else {
            debug.print("novalue: {} {s}\r\n", .{ buffer[0], buffer });
        }
    }
    //while (true) {
    //    var str = try get_string();
    //    var val = try parse_str(str);
    //    std.debug.print("{any}", .{val});
    //}
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

    //_ = try stdout.write(">> ");

    //while (true) {
    //    _ = try stdin_r.readUntilDelimiterOrEof(buf[0..], 'a');
    //    //stdin.
    //    std.debug.print("b: {any}\n", .{buf});
    //}
    //_ = try stdin_r.readUntilDelimiterOrEof(buf[0..], '\n');

    //var found = std.mem.indexOf(u8, buf[0..], "\n").?;

    //return buf[0..];
}

fn parse_str(str: []u8) !i8 {
    var splits = std.mem.split(u8, str, " ");
    var len: usize = 0;
    while (splits.next()) |_| {
        len += 1;
    }
    splits.reset();
    return 0;
    //var first = splits.next().?;
    //var v_type: Type = if (cmp_type(first, 1)) {
    //    .int;
    //} else if (false) {
    //    .char;
    //};
    //var v: Variable = Variable{ .type = v_type, .value = undefined };
    //return v;
}

fn cmp_type(str: []const u8, index: usize) bool {
    return std.mem.eql(u8, str, types[index]);
}
