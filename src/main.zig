// main.zig
const std = @import("std");

const terminal = @import("terminal.zig");
const evaluate = @import("evaluate.zig");
const lexer = @import("lexer.zig");
const types = @import("types.zig");

const c = terminal.c;

pub var buf: [100]u8 = undefined;
var promt_v: terminal.Prompt = .start;
var variables = std.StringHashMap(types.Variable).init(
    std.heap.page_allocator,
);
pub var mb_index: usize = 0; // main buffer index

pub fn main() !void {
    var stdout = std.fs.File.stdout().writer(&.{});
    const init = try terminal.initTerminal();
    defer {
        _ = c.tcsetattr(init.tty.handle, c.TCSANOW, &init.termios);
        init.tty.close();
    }

    // Usamos un ArrayList para construir la línea de entrada dinámicamente.
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var history = std.ArrayList([]u8){};
    defer {
        for (history.items) |h| allocator.free(h);
        history.deinit(allocator);
    }

    main_loop: while (true) {
        var line = std.ArrayList(u8){};
        defer line.deinit(allocator);
        var cursor_pos: usize = 0;

        try stdout.interface.print("c11> ", .{});

        while (true) {
            var char_buf: [1]u8 = undefined;
            const bytes_read = try init.tty.read(&char_buf);

            if (bytes_read == 0) continue;
            const char = char_buf[0];

            switch (char) {
                // Secuencia de escape (Flechas, etc)
                '\x1B' => {
                    var seq: [2]u8 = undefined;
                    if ((try init.tty.read(&seq)) >= 2) {
                        if (seq[0] == '[') {
                            switch (seq[1]) {
                                'A' => { // Flecha Arriba (Historial)
                                    if (history.items.len > 0) {
                                        // Borrar visualmente hasta el inicio del prompt
                                        while (cursor_pos > 0) {
                                            try stdout.interface.print("\x1B[D", .{});
                                            cursor_pos -= 1;
                                        }
                                        try stdout.interface.print("\x1B[K", .{}); // Limpiar hasta el final
                                        
                                        line.clearRetainingCapacity();
                                        const last = history.items[history.items.len - 1];
                                        try line.appendSlice(allocator, last);
                                        try stdout.interface.print("{s}", .{last});
                                        cursor_pos = line.items.len;
                                    }
                                },
                                'C' => { // Flecha Derecha
                                    if (cursor_pos < line.items.len) {
                                        try stdout.interface.print("\x1B[C", .{});
                                        cursor_pos += 1;
                                    }
                                },
                                'D' => { // Flecha Izquierda
                                    if (cursor_pos > 0) {
                                        try stdout.interface.print("\x1B[D", .{});
                                        cursor_pos -= 1;
                                    }
                                },
                                else => {},
                            }
                        }
                    }
                },

                // Enter: Fin de la línea
                '\r' => {
                    try stdout.interface.print("\r\n", .{});
                    break;
                },

                // Ctrl+C: Salir
                3 => {
                    try stdout.interface.print("\r\n", .{});
                    return;
                },
                
                // Backspace
                127 => {
                    if (cursor_pos > 0) {
                        _ = line.orderedRemove(cursor_pos - 1);
                        cursor_pos -= 1;
                        // Mover cursor atrás, redibujar el resto, limpiar final, volver a posición
                        try stdout.interface.print("\x1B[D\x1B[K{s}", .{line.items[cursor_pos..]});
                        var j: usize = 0;
                        while (j < line.items.len - cursor_pos) : (j += 1) {
                            try stdout.interface.print("\x1B[D", .{});
                        }
                    }
                },

                else => {
                    try line.insert(allocator, cursor_pos, char);
                    // Imprimir carácter e insertar en medio redibujando el resto
                    try stdout.interface.print("{c}{s}", .{ char, line.items[cursor_pos + 1 ..] });
                    cursor_pos += 1;
                    // Volver el cursor a su sitio si no estamos al final
                    var j: usize = 0;
                    while (j < line.items.len - cursor_pos) : (j += 1) {
                        try stdout.interface.print("\x1B[D", .{});
                    }
                },
            }
        }

        if (line.items.len > 0) {
            if (std.mem.eql(u8, line.items, "quit")) break :main_loop;

            const h_entry = try allocator.dupe(u8, line.items);
            try history.append(allocator, h_entry);

            parse_str(line.items) catch |err| {
                try stdout.interface.print("Error: {}\r\n", .{err});
            };
        }
    }
}

fn get_string(index: usize, char: u8) void {
    buf[index] = char;
}

fn parse_str(input: []const u8) !void {
    var stdout = std.fs.File.stdout().writer(&.{});
    var instruction_list = try lexer.create_instruction(input);
    defer {
        for (instruction_list.items) |item| {
            std.heap.page_allocator.free(item.string);
        }
        instruction_list.deinit(std.heap.page_allocator);
    }

    const tokens = instruction_list.items;
    if (tokens.len == 0) return;

    const res_opt = try evaluate.exec(tokens, &variables);
    if (res_opt) |res| {
        try stdout.interface.print("=> ", .{});
        try evaluate.printValue(&stdout.interface, res);
        try stdout.interface.print("\r\n", .{});
    }
}
