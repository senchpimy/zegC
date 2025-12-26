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
const types = @import("types.zig");

const c = @cImport({
    @cInclude("termios.h");
    @cInclude("unistd.h");
});

const stdout = std.io.getStdOut().writer();
pub var buf: [100]u8 = undefined;
var promt_v: terminal.Prompt = .start;
var variables = std.StringHashMap(types.Variable).init(
    std.heap.page_allocator,
);
pub var mb_index: usize = 0; // main buffer index

pub fn main() !void {
    const init = try terminal.initTerminal();
    defer {
        _ = c.tcsetattr(init.tty.handle, c.TCSANOW, &init.termios);
        init.tty.close();
    }

    // Usamos un ArrayList para construir la línea de entrada dinámicamente.
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    main_loop: while (true) {
        var line = std.ArrayList(u8).init(allocator);
        defer line.deinit();

        // 1. Imprime el prompt UNA VEZ por línea de comando.
        try std.io.getStdOut().writer().print("c11> ", .{});

        // 2. Bucle INTERNO para leer caracteres hasta presionar Enter.
        while (true) {
            var char_buf: [1]u8 = undefined;
            const bytes_read = try init.tty.read(&char_buf);

            // Si por alguna razón no se lee nada (improbable con nuestra config), continuamos.
            if (bytes_read == 0) continue;

            const char = char_buf[0];

            switch (char) {
                // Enter: Fin de la línea
                '\r' => {
                    try std.io.getStdOut().writer().print("\r\n", .{}); // Nueva línea en la salida
                    break; // Rompe el bucle interno
                },

                // Ctrl+C: Salir del programa
                3 => {
                    try std.io.getStdOut().writer().print("\r\n", .{});
                    return; // Sale de main
                },

                // Ctrl+D: Final de entrada
                4 => {
                    try std.io.getStdOut().writer().print("\r\n", .{});
                    return;
                },

                // Backspace (ASCII 127)
                127 => {
                    if (line.items.len > 0) {
                        _ = line.pop();
                        // Mueve el cursor atrás, imprime un espacio, mueve el cursor atrás de nuevo.
                        try std.io.getStdOut().writer().print("\x1B[D \x1B[D", .{});
                    }
                },

                // Caracter normal: Añádelo a la línea y muéstralo en pantalla.
                else => {
                    try line.append(char);
                    try std.io.getStdOut().writer().print("{c}", .{char});
                },
            }
        }

        // 3. Ahora que tienes la línea completa, procésala.
        // `line.items` es un `[]u8` con el comando del usuario.
        if (std.mem.eql(u8, line.items, "quit")) {
            break :main_loop; // Salimos del bucle principal
        }

        // Simplemente imprimimos la línea recibida como demostración.
        try std.io.getStdOut().writer().print("Comando recibido: '{s}'\r\n", .{line.items});
    }
}

fn get_string(index: usize, char: u8) void {
    buf[index] = char;
}

fn parse_str() !void {
    var instruction_list = try lexer.create_instruction(buf[0..mb_index]);
    defer {
        for (instruction_list.items) |item| {
            std.heap.page_allocator.free(item.string);
        }
        instruction_list.deinit();
    }

    const tokens = instruction_list.items;
    if (tokens.len == 0) return;

    const res_opt = try evaluate.exec(tokens, &variables);
    if (res_opt) |res| {
        try stdout.print("=> ", .{});
        try evaluate.printValue(stdout, res);
    }
}
