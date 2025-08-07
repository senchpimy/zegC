const std = @import("std");
const testing = std.testing;
const main = @import("main.zig");

test "create_instruction test" {
    main.buf[0] = 'i';
    main.buf[1] = 'n';
    main.buf[2] = 't';
    main.buf[3] = ' ';
    main.buf[4] = 'a';
    main.buf[5] = ' ';
    main.buf[6] = '=';
    main.buf[7] = ' ';
    main.buf[8] = '5';
    main.buf[9] = ';';
    main.mb_index = 10;

    const instructions = try main.create_instruction();
    defer instructions.deinit();

    try testing.expect(instructions.items.len == 4);
    try testing.expect(instructions.items[0].type == .TypeDeclaration);
    try testing.expect(std.mem.eql(u8, instructions.items[0].string, "int"));
    try testing.expect(instructions.items[1].type == .Value);
    try testing.expect(std.mem.eql(u8, instructions.items[1].string, "a"));
    try testing.expect(instructions.items[2].type == .Assignation);
    try testing.expect(std.mem.eql(u8, instructions.items[2].string, "="));
    try testing.expect(instructions.items[3].type == .Value);
    try testing.expect(std.mem.eql(u8, instructions.items[3].string, "5"));
}
