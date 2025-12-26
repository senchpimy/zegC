// src/terminal.zig
const std = @import("std");

pub const c = @cImport({
    @cInclude("termios.h");
    @cInclude("unistd.h");
});

pub const Prompt = enum { start, cont };

pub const Init = struct {
    tty: std.fs.File,
    termios: c.termios,
};

pub fn initTerminal() !Init {
    var tty = try std.fs.openFileAbsolute("/dev/tty", .{
        .mode = .read_write,
    });

    var orig: c.termios = undefined;
    if (c.tcgetattr(tty.handle, &orig) != 0) {
        tty.close();
        return error.TcgetattrFailed;
    }

    var raw = orig;

    // --- CORRECCIÓN AQUÍ ---
    // Hacemos un cast al tipo correcto ANTES de la negación a nivel de bits.
    raw.c_lflag &= ~@as(c.tcflag_t, c.ECHO | c.ICANON | c.IEXTEN | c.ISIG);
    raw.c_iflag &= ~@as(c.tcflag_t, c.IXON | c.ICRNL | c.BRKINT | c.INPCK | c.ISTRIP);
    raw.c_oflag &= ~@as(c.tcflag_t, c.OPOST);
    // --- FIN DE LA CORRECCIÓN ---

    raw.c_cflag |= c.CS8;
    raw.c_cc[c.VMIN] = 1;
    raw.c_cc[c.VTIME] = 0;

    if (c.tcsetattr(tty.handle, c.TCSANOW, &raw) != 0) {
        tty.close();
        return error.TcsetattrFailed;
    }

    return .{ .tty = tty, .termios = orig };
}

pub fn prompt(p: *Prompt) !void {
    var out = std.fs.File.stdout().writer(&.{});
    switch (p.*) {
        .start => try out.interface.print("\r\nc11> ", .{}),
        .cont => try out.interface.print("\r\n...> ", .{}),
    }
}
