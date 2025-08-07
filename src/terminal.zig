const std = @import("std");
const fs = std.fs;
const os = std.os;
const io = std.io;

pub const Prompt = enum { start, none, cont };

var buf: [100]u8 = undefined;
var npromt_v: Prompt = .start;
var mb_index: u32 = 0;
const stdout = io.getStdOut().writer();
const c = @cImport({
    @cInclude("termios.h");
});

pub fn initTerminal() !struct { tty: fs.File, termios: os.linux.termios } {
    var termios: std.os.linux.termios = undefined;
    const tty = fs.cwd().openFile("/dev/tty", fs.File.OpenFlags{ .mode = .read_write }) catch |err| switch (err) {
        error.NoDevice => return error.NoTty,
        else => return err,
    };

    const ret = std.os.linux.tcgetattr(tty.handle, &termios);
    if (ret != 0) {
        std.debug.print("tcgetattr failed with code {}\n", .{ret});
        return error.TcgetattrFailed;
    }

    var raw = termios;

    raw.lflag.ECHO = false;
    raw.lflag.ICANON = false;
    raw.lflag.ISIG = false;
    raw.lflag.IEXTEN = false;

    raw.iflag.IXON = false;
    raw.iflag.ICRNL = false;
    raw.iflag.BRKINT = false;
    raw.iflag.INPCK = false;
    raw.iflag.ISTRIP = false;

    raw.cc[c.VTIME] = 0;
    raw.cc[c.VMIN] = 1;
    _ = os.linux.tcsetattr(tty.handle, .FLUSH, &raw);
    return .{ .tty = tty, .termios = termios };
}

pub fn restoreTerminal(original: os.termios) !void {
    const tty = try fs.cwd().openFile("/dev/tty", .{ .mode = .read_write });
    defer tty.close();
    try os.tcsetattr(tty.handle, .FLUSH, original);
}

pub fn prompt(promt_v: *Prompt) !void {
    const prompt_str = switch (promt_v.*) {
        .start => ">>>",
        .cont => "\n...",
        .none => return,
    };
    try stdout.print("{s}", .{prompt_str});
    promt_v.* = .none;
}

pub fn handleInput(char: u8, promt_v: Prompt) !?[]const u8 {
    if (char == 0x1B) { // Escape sequence
        return null;
    } else if (char == 3) { // Ctrl+C
        return error.Terminate;
    } else if (char == 0x7F or char == 0x08) { // Backspace
        if (mb_index > 0) {
            mb_index -= 1;
            buf[mb_index] = 0;
            try stdout.print("\x1B[D \x1B[D", .{});
        }
    } else if (char == '\r') { // Enter
        if (mb_index > 0 and buf[mb_index - 1] == ';') {
            const input = buf[0..mb_index];
            promt_v = .start;
            return input;
        }
        promt_v = .cont;
    } else if (std.ascii.isASCII(char)) {
        buf[mb_index] = char;
        mb_index += 1;
        try stdout.print("{c}", .{char});
    }
    return null;
}

pub fn getCurrentBuffer() []const u8 {
    return buf[0..mb_index];
}

pub fn resetBuffer() void {
    mb_index = 0;
    @memset(&buf, 0);
}
