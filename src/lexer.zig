const std = @import("std");
const debug = std.debug;

const types = @import("types.zig");

pub const primitive_types = [_][]const u8{ "int", "char", "long", "bool", "void", "double", "float" };
const keywords = [_][]const u8{ "if", "else", "for", "while", "do", "struct" };
const asignation_operations = [_][]const u8{ "=", "+=", "-=", "*=", "/=", "%=", "&=", "|=", "<<=", ">>=" };
const primitive_operations = [_][]const u8{ "+", "-", "*", "/", "%", "&&", "||", "!", "==", "!=", ">", "<", ">=", "<=", "&", "|", "^", "~", "<<", ">>" };

pub fn create_instruction(buffer: []const u8) !std.ArrayList(types.Instruction) {
    var list = std.ArrayList(types.Instruction).init(std.heap.page_allocator);
    var instructions = std.mem.tokenizeScalar(u8, buffer, ';');

    while (instructions.next()) |intrs| {
        var splits = std.mem.splitAny(u8, std.mem.trim(u8, intrs, &std.ascii.whitespace), &std.ascii.whitespace);
        while (splits.next()) |str| {
            if (str.len == 0) {
                continue;
            }

            const string = try std.heap.page_allocator.dupe(u8, str);
            var found_token = false;

            for (primitive_types, 0..) |typ, i| {
                if (std.mem.eql(u8, string, typ)) {
                    try list.append(types.Instruction{ .type = .TypeDeclaration, .string = string, .index = @intCast(i) });
                    found_token = true;
                    break;
                }
            }
            if (found_token) continue;

            for (asignation_operations, 0..) |op, i| {
                if (std.mem.eql(u8, string, op)) {
                    try list.append(types.Instruction{ .type = .Assignation, .string = string, .index = @intCast(i) });
                    found_token = true;
                    break;
                }
            }
            if (found_token) continue;

            for (keywords, 0..) |kw, i| {
                if (std.mem.eql(u8, string, kw)) {
                    try list.append(types.Instruction{ .type = .Keywords, .string = string, .index = @intCast(i) });
                    found_token = true;
                    debug.print("Keyword {s}", .{string});
                    break;
                }
            }
            if (found_token) continue;

            try list.append(types.Instruction{ .type = .Value, .string = string, .index = -1 });
        }
    }
    return list;
}

pub fn match_type(index: i16) types.Type {
    return @enumFromInt(index);
}

pub fn match_payload(t: types.Type) types.Payload {
    return switch (t) {
        .int => types.Payload{ .int = undefined },
        .char => types.Payload{ .char = undefined },
        .long => types.Payload{ .long = undefined },
        .boolean => types.Payload{ .boolean = undefined },
        .void => types.Payload{ .void = undefined },
        .double => types.Payload{ .double = undefined },
        .float => types.Payload{ .float = undefined },
    };
}
