const std = @import("std");
const types = @import("types.zig");
const debug = std.debug;

const primitive_types = [_][]const u8{
    "int", "char", "long", "bool", "void", "double", "float",
};
const keywords = [_][]const u8{ "if", "else", "for", "while", "do", "struct" };

fn isSpace(c: u8) bool {
    return std.ascii.isWhitespace(c);
}

fn isDigit(c: u8) bool {
    return c >= '0' and c <= '9';
}

fn isIdentStart(c: u8) bool {
    return (c == '_') or (c >= 'A' and c <= 'Z') or (c >= 'a' and c <= 'z');
}

fn isIdentPart(c: u8) bool {
    return isIdentStart(c) or isDigit(c);
}

fn matchesAny(s: []const u8, arr: anytype) i16 {
    for (arr, 0..) |a, i| {
        if (std.mem.eql(u8, s, a)) return @intCast(i);
    }
    return -1;
}

fn dupStr(s: []const u8) ![]u8 {
    return try std.heap.page_allocator.dupe(u8, s);
}

pub fn create_instruction(buffer: []const u8) !std.ArrayList(types.Instruction) {
    const allocator = std.heap.page_allocator;
    var list = std.ArrayList(types.Instruction){};

    var i: usize = 0;
    const n = buffer.len;
    while (i < n) {
        const c = buffer[i];

        // Fin de sentencia
        if (c == ';') break;

        // Saltar espacios
        if (isSpace(c)) {
            i += 1;
            continue;
        }

        // Comentarios simples // ... (opcional)
        if (c == '/' and i + 1 < n and buffer[i + 1] == '/') {
            // Rest of line is comment; stop.
            break;
        }

        // Char literal
        if (c == '\'') {
            const start = i;
            i += 1;
            if (i >= n) return error.InvalidCharacter;
            if (buffer[i] == '\\') {
                i += 1;
                if (i >= n) return error.InvalidCharacter;
                // escape + following char(s)
                if (buffer[i] == 'x') {
                    i += 1;
                    // hex digits (1-2) until closing quote
                    var hexc: usize = 0;
                    while (i < n and hexc < 2) : (i += 1) {
                        const d = buffer[i];
                        _ = std.fmt.charToDigit(d, 16) catch break;
                        hexc += 1;
                    }
                } else {
                    // common escape, just skip one char
                    i += 0;
                }
                if (i >= n) return error.InvalidCharacter;
            } else {
                // regular char
                if (i >= n) return error.InvalidCharacter;
                i += 0;
            }
            // Buscar cierre '
            i += 1;
            if (i >= n or buffer[i] != '\'')
                return error.InvalidCharacter;
            i += 1;
            const s = try dupStr(buffer[start..i]);
            try list.append(allocator, .{
                .type = .Value,
                .string = s,
                .index = -1,
            });
            continue;
        }

        // Identificadores o palabras clave o tipos
        if (isIdentStart(c)) {
            const start = i;
            i += 1;
            while (i < n and isIdentPart(buffer[i])) : (i += 1) {}
            const s = try dupStr(buffer[start..i]);

            // Tipos primitivos
            const ti = matchesAny(s, primitive_types);
            if (ti >= 0) {
                try list.append(allocator, .{
                    .type = .TypeDeclaration,
                    .string = s,
                    .index = ti,
                });
                continue;
            }

            // Keywords
            const ki = matchesAny(s, keywords);
            if (ki >= 0) {
                try list.append(allocator, .{
                    .type = .Keywords,
                    .string = s,
                    .index = ki,
                });
                debug.print("Keyword {s}", .{s});
                continue;
            }

            // Valor (identificador, true/false, etc.)
            try list.append(allocator, .{ .type = .Value, .string = s, .index = -1 });
            continue;
        }

        // Números (enteros, floats, con sufijos f/F/l/L)
        if (isDigit(c) or c == '.') {
            const start = i;
            var has_dot_or_exp = false;

            if (c == '.') {
                i += 1;
                while (i < n and isDigit(buffer[i])) : (i += 1) {}
            } else {
                while (i < n and isDigit(buffer[i])) : (i += 1) {}
                if (i < n and buffer[i] == '.') {
                    has_dot_or_exp = true;
                    i += 1;
                    while (i < n and isDigit(buffer[i])) : (i += 1) {}
                }
            }
            if (i < n and (buffer[i] == 'e' or buffer[i] == 'E')) {
                has_dot_or_exp = true;
                i += 1;
                if (i < n and (buffer[i] == '+' or buffer[i] == '-')) i += 1;
                while (i < n and isDigit(buffer[i])) : (i += 1) {}
            }
            // Sufijos f/F o l/L
            if (i < n and (buffer[i] == 'f' or buffer[i] == 'F' or
                buffer[i] == 'l' or buffer[i] == 'L'))
            {
                i += 1;
            }

            const s = try dupStr(buffer[start..i]);
            try list.append(allocator, .{ .type = .Value, .string = s, .index = -1 });
            continue;
        }

        // Operadores y paréntesis (chequear primero los más largos)
        // 3-char: <<=, >>=
        if (i + 2 < n) {
            const tri = buffer[i .. i + 3];
            if (std.mem.eql(u8, tri, "<<=") or std.mem.eql(u8, tri, ">>=")) {
                const s = try dupStr(tri);
                try list.append(allocator, .{
                    .type = .Assignation,
                    .string = s,
                    .index = -1,
                });
                i += 3;
                continue;
            }
        }

        // 2-char operadores
        if (i + 1 < n) {
            const two = buffer[i .. i + 2];
            const two_ops = [_][]const u8{
                "==", "!=", ">=", "<=", "&&", "||", "<<", ">>", "+=", "-=",
                "*=", "/=", "%=", "&=", "|=",
            };
            var matched: bool = false;
            for (two_ops) |op| {
                if (std.mem.eql(u8, two, op)) {
                    const s = try dupStr(two);
                    const is_assign = (op.len == 2 and op[1] == '=' and
                        (op[0] != '=' and op[0] != '!' and op[0] != '<' and
                            op[0] != '>'));
                    if (is_assign) {
                        try list.append(allocator, .{
                            .type = .Assignation,
                            .string = s,
                            .index = -1,
                        });
                        i += 2;
                        matched = true;
                        break;
                    } else {
                        try list.append(allocator, .{
                            .type = .Operation,
                            .string = s,
                            .index = -1,
                        });
                        i += 2;
                        matched = true;
                        break;
                    }
                }
            }
            if (matched) continue;
        }

        // 1-char operadores y paréntesis
        {
            const ch = buffer[i];
            const one = buffer[i .. i + 1];
            const s = try dupStr(one);

            switch (ch) {
                '=' => {
                    try list.append(allocator, .{
                        .type = .Assignation,
                        .string = s,
                        .index = -1,
                    });
                    i += 1;
                    continue;
                },
                '+', '-', '*', '/', '%', '&', '|', '^', '~', '!', '(', ')', '<', '>' => {
                    try list.append(allocator, .{
                        .type = .Operation,
                        .string = s,
                        .index = -1,
                    });
                    i += 1;
                    continue;
                },
                else => return error.InvalidCharacter,
            }
        }
    }

    return list;
}
