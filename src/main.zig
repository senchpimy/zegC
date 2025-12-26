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

    main_loop: while (true) {
        var line = std.ArrayList(u8){};
        defer line.deinit(allocator);

        // 1. Imprime el prompt UNA VEZ por línea de comando.
        try stdout.interface.print("c11> ", .{});

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
                    try stdout.interface.print("\r\n", .{}); // Nueva línea en la salida
                    break; // Rompe el bucle interno
                },

                // Ctrl+C: Salir del programa
                3 => {
                    try stdout.interface.print("\r\n", .{});
                    return; // Sale de main
                },

                // Ctrl+D: Final de entrada
                4 => {
                    try stdout.interface.print("\r\n", .{});
                    return;
                },

                // Backspace (ASCII 127)
                127 => {
                    if (line.items.len > 0) {
                        _ = line.pop();
                        // Mueve el cursor atrás, imprime un espacio, mueve el cursor atrás de nuevo.
                        try stdout.interface.print("\x1B[D \x1B[D", .{});
                    }
                },

                // Caracter normal: Añádelo a la línea y muéstralo en pantalla.
                else => {
                    try line.append(allocator, char);
                    try stdout.interface.print("{c}", .{char});
                },
            }
        }

        // 3. Ahora que tienes la línea completa, procésala.
        if (std.mem.eql(u8, line.items, "quit")) {
            break :main_loop;
        }

        if (line.items.len > 0) {
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
