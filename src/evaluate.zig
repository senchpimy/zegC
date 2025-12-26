const std = @import("std");
const types = @import("types.zig");

pub const VarMap = std.StringHashMap(types.Variable);

pub const Value = struct {
    t: types.Type,
    p: types.Payload,
};

const Assoc = enum { Left, Right };

const OpTag = enum {
    // Binarios
    Mul,
    Div,
    Mod,
    Add,
    Sub,
    Shl,
    Shr,
    Lt,
    Le,
    Gt,
    Ge,
    Eq,
    Ne,
    BitAnd,
    BitXor,
    BitOr,
    LogAnd,
    LogOr,

    // Unarios
    UMinus,
    Not,
    BitNot,

    // Paréntesis
    LParen,
    RParen,
};

fn precedence(tag: OpTag) u8 {
    return switch (tag) {
        .UMinus, .Not, .BitNot => 2,
        .Mul, .Div, .Mod => 3,
        .Add, .Sub => 4,
        .Shl, .Shr => 5,
        .Lt, .Le, .Gt, .Ge => 6,
        .Eq, .Ne => 7,
        .BitAnd => 8,
        .BitXor => 9,
        .BitOr => 10,
        .LogAnd => 11,
        .LogOr => 12,
        .LParen, .RParen => 100,
    };
}

fn associativity(tag: OpTag) Assoc {
    return switch (tag) {
        .UMinus, .Not, .BitNot => .Right,
        else => .Left,
    };
}

fn isDigit(c: u8) bool {
    return c >= '0' and c <= '9';
}

fn isIdentifierStart(c: u8) bool {
    return (c == '_') or (c >= 'A' and c <= 'Z') or (c >= 'a' and c <= 'z');
}

fn isIdentifierPart(c: u8) bool {
    return isIdentifierStart(c) or isDigit(c);
}

fn eql(a: []const u8, b: []const u8) bool {
    return std.mem.eql(u8, a, b);
}

fn mapOp(op: []const u8, is_unary: bool) ?OpTag {
    if (is_unary) {
        if (eql(op, "-")) return .UMinus;
        if (eql(op, "!")) return .Not;
        if (eql(op, "~")) return .BitNot;
        return null;
    }
    if (eql(op, "*")) return .Mul;
    if (eql(op, "/")) return .Div;
    if (eql(op, "%")) return .Mod;
    if (eql(op, "+")) return .Add;
    if (eql(op, "-")) return .Sub;
    if (eql(op, "<<")) return .Shl;
    if (eql(op, ">>")) return .Shr;
    if (eql(op, "<")) return .Lt;
    if (eql(op, "<=")) return .Le;
    if (eql(op, ">")) return .Gt;
    if (eql(op, ">=")) return .Ge;
    if (eql(op, "==")) return .Eq;
    if (eql(op, "!=")) return .Ne;
    if (eql(op, "&")) return .BitAnd;
    if (eql(op, "^")) return .BitXor;
    if (eql(op, "|")) return .BitOr;
    if (eql(op, "&&")) return .LogAnd;
    if (eql(op, "||")) return .LogOr;
    if (eql(op, "(")) return .LParen;
    if (eql(op, ")")) return .RParen;
    return null;
}

fn toBool(v: Value) bool {
    return switch (v.t) {
        .boolean => v.p.boolean,
        .char => v.p.char != 0,
        .int => v.p.int != 0,
        .long => v.p.long != 0,
        .float => v.p.float != 0.0,
        .double => v.p.double != 0.0,
        .void => false,
    };
}

fn asInt64(v: Value) i64 {
    return switch (v.t) {
        .boolean => if (v.p.boolean) 1 else 0,
        .char => v.p.char,
        .int => v.p.int,
        .long => v.p.long,
        .float => @intFromFloat(v.p.float),
        .double => @intFromFloat(v.p.double),
        .void => 0,
    };
}

fn asInt32(v: Value) i32 {
    return @as(i32, @intCast(asInt64(v)));
}

fn asFloat32(v: Value) f32 {
    return switch (v.t) {
        .boolean => if (v.p.boolean) 1 else 0,
        .char => @floatFromInt(v.p.char),
        .int => @floatFromInt(v.p.int),
        .long => @floatFromInt(v.p.long),
        .float => v.p.float,
        .double => @floatCast(v.p.double),
        .void => 0.0,
    };
}

fn asFloat64(v: Value) f64 {
    return switch (v.t) {
        .boolean => if (v.p.boolean) 1 else 0,
        .char => @floatFromInt(v.p.char),
        .int => @floatFromInt(v.p.int),
        .long => @floatFromInt(v.p.long),
        .float => v.p.float,
        .double => v.p.double,
        .void => 0.0,
    };
}

fn promote2(a: Value, b: Value) types.Type {
    if (a.t == .double or b.t == .double) return .double;
    if (a.t == .float or b.t == .float) return .float;
    const at = if (a.t == .char or a.t == .boolean) types.Type.int else a.t;
    const bt = if (b.t == .char or b.t == .boolean) types.Type.int else b.t;
    if (at == .long or bt == .long) return .long;
    return .int;
}

fn convert(to: types.Type, v: Value) Value {
    switch (to) {
        .boolean => {
            return Value{
                .t = .boolean,
                .p = .{ .boolean = toBool(v) },
            };
        },
        .char => {
            const x: u8 = @as(u8, @intCast(asInt64(v)));
            return Value{ .t = .char, .p = .{ .char = x } };
        },
        .int => {
            return Value{ .t = .int, .p = .{ .int = asInt32(v) } };
        },
        .long => {
            return Value{ .t = .long, .p = .{ .long = asInt64(v) } };
        },
        .float => {
            return Value{ .t = .float, .p = .{ .float = asFloat32(v) } };
        },
        .double => {
            return Value{ .t = .double, .p = .{ .double = asFloat64(v) } };
        },
        .void => {
            return Value{ .t = .void, .p = .{ .void = 0 } };
        },
    }
}

fn applyUnary(op: OpTag, a: Value) !Value {
    return switch (op) {
        .UMinus => switch (a.t) {
            .double => Value{ .t = .double, .p = .{ .double = -a.p.double } },
            .float => Value{ .t = .float, .p = .{ .float = -a.p.float } },
            .long => Value{ .t = .long, .p = .{ .long = -a.p.long } },
            .int => Value{ .t = .int, .p = .{ .int = -a.p.int } },
            .char => Value{
                .t = .int,
                .p = .{ .int = -@as(i32, a.p.char) },
            },
            .boolean => Value{
                .t = .int,
                .p = .{ .int = if (a.p.boolean) -1 else 0 },
            },
            .void => return types.ParsingError.TypeMismatch,
        },
        .Not => Value{ .t = .boolean, .p = .{ .boolean = !toBool(a) } },
        .BitNot => {
            const iv = asInt64(a);
            return Value{ .t = .long, .p = .{ .long = ~iv } };
        },
        else => return types.ParsingError.SyntaxError,
    };
}

fn applyBinary(op: OpTag, a: Value, b: Value) !Value {
    switch (op) {
        .Add, .Sub, .Mul, .Div, .Mod => {
            const tgt = promote2(a, b);
            const A = convert(tgt, a);
            const B = convert(tgt, b);
            return switch (tgt) {
                .double => switch (op) {
                    .Add => Value{
                        .t = .double,
                        .p = .{ .double = A.p.double + B.p.double },
                    },
                    .Sub => Value{
                        .t = .double,
                        .p = .{ .double = A.p.double - B.p.double },
                    },
                    .Mul => Value{
                        .t = .double,
                        .p = .{ .double = A.p.double * B.p.double },
                    },
                    .Div => {
                        if (B.p.double == 0.0)
                            return types.ParsingError.InvalidValue;
                        return Value{
                            .t = .double,
                            .p = .{ .double = A.p.double / B.p.double },
                        };
                    },
                    .Mod => return types.ParsingError.TypeMismatch,
                    else => unreachable,
                },
                .float => switch (op) {
                    .Add => Value{
                        .t = .float,
                        .p = .{ .float = A.p.float + B.p.float },
                    },
                    .Sub => Value{
                        .t = .float,
                        .p = .{ .float = A.p.float - B.p.float },
                    },
                    .Mul => Value{
                        .t = .float,
                        .p = .{ .float = A.p.float * B.p.float },
                    },
                    .Div => {
                        if (B.p.float == 0.0)
                            return types.ParsingError.InvalidValue;
                        return Value{
                            .t = .float,
                            .p = .{ .float = A.p.float / B.p.float },
                        };
                    },
                    .Mod => return types.ParsingError.TypeMismatch,
                    else => unreachable,
                },
                .long => switch (op) {
                    .Add => Value{
                        .t = .long,
                        .p = .{ .long = A.p.long + B.p.long },
                    },
                    .Sub => Value{
                        .t = .long,
                        .p = .{ .long = A.p.long - B.p.long },
                    },
                    .Mul => Value{
                        .t = .long,
                        .p = .{ .long = A.p.long * B.p.long },
                    },
                    .Div => {
                        if (B.p.long == 0) return types.ParsingError.InvalidValue;
                        return Value{
                            .t = .long,
                            .p = .{ .long = @divTrunc(A.p.long, B.p.long) },
                        };
                    },
                    .Mod => {
                        if (B.p.long == 0) return types.ParsingError.InvalidValue;
                        return Value{
                            .t = .long,
                            .p = .{ .long = @mod(A.p.long, B.p.long) },
                        };
                    },
                    else => unreachable,
                },
                .int => switch (op) {
                    .Add => Value{
                        .t = .int,
                        .p = .{ .int = A.p.int + B.p.int },
                    },
                    .Sub => Value{
                        .t = .int,
                        .p = .{ .int = A.p.int - B.p.int },
                    },
                    .Mul => Value{
                        .t = .int,
                        .p = .{ .int = A.p.int * B.p.int },
                    },
                    .Div => {
                        if (B.p.int == 0) return types.ParsingError.InvalidValue;
                        return Value{
                            .t = .int,
                            .p = .{ .int = @divTrunc(A.p.int, B.p.int) },
                        };
                    },
                    .Mod => {
                        if (B.p.int == 0) return types.ParsingError.InvalidValue;
                        return Value{
                            .t = .int,
                            .p = .{ .int = @mod(A.p.int, B.p.int) },
                        };
                    },
                    else => unreachable,
                },
                else => return types.ParsingError.TypeMismatch,
            };
        },
        .Shl, .Shr, .BitAnd, .BitXor, .BitOr => {
            const A = convert(.long, a);
            const B = convert(.long, b);
            return switch (op) {
                //.Shl => Value{
                //    .t = .long,
                //    .p = .{ .long = A.p.long << @intCast(u6, B.p.long & 63) },
                //},
                //.Shr => Value{
                //    .t = .long,
                //    .p = .{ .long = A.p.long >> @intCast(u6, B.p.long & 63) },
                //},
                .BitAnd => Value{
                    .t = .long,
                    .p = .{ .long = A.p.long & B.p.long },
                },
                .BitXor => Value{
                    .t = .long,
                    .p = .{ .long = A.p.long ^ B.p.long },
                },
                .BitOr => Value{
                    .t = .long,
                    .p = .{ .long = A.p.long | B.p.long },
                },
                else => unreachable,
            };
        },
        .Lt, .Le, .Gt, .Ge, .Eq, .Ne => {
            const tgt = promote2(a, b);
            const A = convert(tgt, a);
            const B = convert(tgt, b);
            const res = switch (tgt) {
                .double => switch (op) {
                    .Lt => A.p.double < B.p.double,
                    .Le => A.p.double <= B.p.double,
                    .Gt => A.p.double > B.p.double,
                    .Ge => A.p.double >= B.p.double,
                    .Eq => A.p.double == B.p.double,
                    .Ne => A.p.double != B.p.double,
                    else => unreachable,
                },
                .float => switch (op) {
                    .Lt => A.p.float < B.p.float,
                    .Le => A.p.float <= B.p.float,
                    .Gt => A.p.float > B.p.float,
                    .Ge => A.p.float >= B.p.float,
                    .Eq => A.p.float == B.p.float,
                    .Ne => A.p.float != B.p.float,
                    else => unreachable,
                },
                .long => switch (op) {
                    .Lt => A.p.long < B.p.long,
                    .Le => A.p.long <= B.p.long,
                    .Gt => A.p.long > B.p.long,
                    .Ge => A.p.long >= B.p.long,
                    .Eq => A.p.long == B.p.long,
                    .Ne => A.p.long != B.p.long,
                    else => unreachable,
                },
                .int => switch (op) {
                    .Lt => A.p.int < B.p.int,
                    .Le => A.p.int <= B.p.int,
                    .Gt => A.p.int > B.p.int,
                    .Ge => A.p.int >= B.p.int,
                    .Eq => A.p.int == B.p.int,
                    .Ne => A.p.int != B.p.int,
                    else => unreachable,
                },
                else => return types.ParsingError.TypeMismatch,
            };
            return Value{ .t = .boolean, .p = .{ .boolean = res } };
        },
        .LogAnd => {
            const res = toBool(a) and toBool(b);
            return Value{ .t = .boolean, .p = .{ .boolean = res } };
        },
        .LogOr => {
            const res = toBool(a) or toBool(b);
            return Value{ .t = .boolean, .p = .{ .boolean = res } };
        },
        else => return types.ParsingError.SyntaxError,
    }
}

fn parseCharLiteral(s: []const u8) !u8 {
    if (s.len < 3 or s[0] != '\'' or s[s.len - 1] != '\'')
        return types.ParsingError.SyntaxError;
    if (s[1] != '\\') {
        if (s.len != 3) return types.ParsingError.SyntaxError;
        return s[1];
    }
    if (s.len < 4) return types.ParsingError.SyntaxError;
    const esc = s[2];
    return switch (esc) {
        'n' => 10,
        't' => 9,
        'r' => 13,
        '0' => 0,
        '\\' => '\\',
        '\'' => '\'',
        '"' => '"',
        'x' => blk: {
            var i: usize = 3;
            var val: u8 = 0;
            var count: usize = 0;
            while (i < s.len - 1 and count < 2) : (i += 1) {
                const c = s[i];
                const hv = std.fmt.charToDigit(c, 16) catch break;
                val = (val << 4) | @as(u8, hv);
                count += 1;
            }
            break :blk val;
        },
        else => return types.ParsingError.SyntaxError,
    };
}

fn parseLiteralOrIdentifier(
    tok: types.Instruction,
    vars: *VarMap,
) !Value {
    const s = tok.string;

    if (s.len >= 2 and s[0] == '\'' and s[s.len - 1] == '\'') {
        const ch = try parseCharLiteral(s);
        return Value{ .t = .char, .p = .{ .char = ch } };
    }

    if (eql(s, "true")) {
        return Value{ .t = .boolean, .p = .{ .boolean = true } };
    }
    if (eql(s, "false")) {
        return Value{ .t = .boolean, .p = .{ .boolean = false } };
    }

    if (s.len > 0 and (isDigit(s[0]) or s[0] == '.')) {
        var end = s.len;
        var is_float = false;
        if (s.len >= 2 and (s[end - 1] == 'f' or s[end - 1] == 'F')) {
            is_float = true;
            end -= 1;
        }
        if (!is_float and s.len >= 2 and (s[end - 1] == 'l' or s[end - 1] == 'L')) {
            const val = try std.fmt.parseInt(i64, s[0..end], 10);
            return Value{ .t = .long, .p = .{ .long = val } };
        }
        var has_dot_or_exp = false;
        for (s[0..end]) |c| {
            if (c == '.' or c == 'e' or c == 'E') {
                has_dot_or_exp = true;
                break;
            }
        }
        if (has_dot_or_exp or is_float) {
            if (is_float) {
                const v = try std.fmt.parseFloat(f32, s[0..end]);
                return Value{ .t = .float, .p = .{ .float = v } };
            } else {
                const v = try std.fmt.parseFloat(f64, s[0..end]);
                return Value{ .t = .double, .p = .{ .double = v } };
            }
        } else {
            const v = try std.fmt.parseInt(i32, s[0..end], 10);
            return Value{ .t = .int, .p = .{ .int = v } };
        }
    }

    const got = vars.get(s);
    if (got == null) return types.ParsingError.UndefinedVariable;
    const varv = got.?;
    return Value{ .t = varv.type, .p = varv.value };
}

fn evalExpr(tokens: []const types.Instruction, vars: *VarMap) !Value {
    var vals = std.ArrayList(Value).init(std.heap.page_allocator);
    defer vals.deinit();
    var ops = std.ArrayList(OpTag).init(std.heap.page_allocator);
    defer ops.deinit();

    var expect_value = true;

    var i: usize = 0;
    while (i < tokens.len) : (i += 1) {
        const tk = tokens[i];

        switch (tk.type) {
            .Value => {
                const v = try parseLiteralOrIdentifier(tk, vars);
                try vals.append(v);
                expect_value = false;
            },
            .Operation => {
                const s = tk.string;

                if (eql(s, "(")) {
                    try ops.append(.LParen);
                    expect_value = true;
                    continue;
                }
                if (eql(s, ")")) {
                    while (ops.items.len > 0) {
                        const top = ops.items[ops.items.len - 1];
                        if (top == .LParen) {
                            _ = ops.pop();
                            break;
                        }
                        const op = ops.pop();
                        if (op == .UMinus or op == .Not or op == .BitNot) {
                            if (vals.items.len < 1)
                                return types.ParsingError.SyntaxError;
                            const a = vals.pop();
                            const r = try applyUnary(op.?, a.?);
                            try vals.append(r);
                        } else {
                            if (vals.items.len < 2)
                                return types.ParsingError.SyntaxError;
                            const b = vals.pop();
                            const a = vals.pop();
                            const r = try applyBinary(op.?, a.?, b.?);
                            try vals.append(r);
                        }
                    }
                    expect_value = false;
                    continue;
                }

                const maybe_unary = expect_value;
                const tag_opt = mapOp(s, maybe_unary);
                if (tag_opt == null) return types.ParsingError.SyntaxError;
                const tag = tag_opt.?;

                if (tag == .LParen or tag == .RParen)
                    return types.ParsingError.SyntaxError;

                while (ops.items.len > 0) {
                    const top = ops.items[ops.items.len - 1];
                    if (top == .LParen) break;
                    const p1 = precedence(tag);
                    const p2 = precedence(top);
                    const a1 = associativity(tag);
                    const cond = switch (a1) {
                        .Left => p1 >= p2,
                        .Right => p1 > p2,
                    };
                    if (!cond) break;

                    const op2 = ops.pop();
                    if (op2 == .UMinus or op2 == .Not or op2 == .BitNot) {
                        if (vals.items.len < 1)
                            return types.ParsingError.SyntaxError;
                        const a = vals.pop();
                        const r = try applyUnary(op2.?, a.?);
                        try vals.append(r);
                    } else {
                        if (vals.items.len < 2)
                            return types.ParsingError.SyntaxError;
                        const b = vals.pop();
                        const a = vals.pop();
                        const r = try applyBinary(op2.?, a.?, b.?);
                        try vals.append(r);
                    }
                }
                try ops.append(tag);
                expect_value = true and
                    (tag != .UMinus and tag != .Not and tag != .BitNot);
            },
            .Assignation, .Keywords, .TypeDeclaration => {
                return types.ParsingError.SyntaxError;
            },
        }
    }

    while (ops.items.len > 0) {
        const op = ops.pop();
        if (op == .LParen or op == .RParen)
            return types.ParsingError.SyntaxError;

        if (op == .UMinus or op == .Not or op == .BitNot) {
            if (vals.items.len < 1) return types.ParsingError.SyntaxError;
            const a = vals.pop();
            const r = try applyUnary(op.?, a.?);
            try vals.append(r);
        } else {
            if (vals.items.len < 2) return types.ParsingError.SyntaxError;
            const b = vals.pop();
            const a = vals.pop();
            const r = try applyBinary(op.?, a.?, b.?);
            try vals.append(r);
        }
    }

    if (vals.items.len != 1) return types.ParsingError.SyntaxError;
    return vals.items[0];
}

fn isIdentifierToken(tok: types.Instruction) bool {
    const s = tok.string;
    if (s.len == 0) return false;
    if (!isIdentifierStart(s[0])) return false;
    for (s[1..]) |c| if (!isIdentifierPart(c)) return false;
    return true;
}

fn assignmentBinaryOp(op: []const u8) ?OpTag {
    if (eql(op, "+=")) return .Add;
    if (eql(op, "-=")) return .Sub;
    if (eql(op, "*=")) return .Mul;
    if (eql(op, "/=")) return .Div;
    if (eql(op, "%=")) return .Mod;
    if (eql(op, "&=")) return .BitAnd;
    if (eql(op, "|=")) return .BitOr;
    if (eql(op, "^=")) return .BitXor;
    if (eql(op, "<<=")) return .Shl;
    if (eql(op, ">>=")) return .Shr;
    return null;
}

fn defaultValue(t: types.Type) Value {
    return switch (t) {
        .int => Value{ .t = .int, .p = .{ .int = 0 } },
        .char => Value{ .t = .char, .p = .{ .char = 0 } },
        .long => Value{ .t = .long, .p = .{ .long = 0 } },
        .boolean => Value{ .t = .boolean, .p = .{ .boolean = false } },
        .void => Value{ .t = .void, .p = .{ .void = 0 } },
        .double => Value{ .t = .double, .p = .{ .double = 0.0 } },
        .float => Value{ .t = .float, .p = .{ .float = 0.0 } },
    };
}

fn storeVar(
    vars: *VarMap,
    name: []const u8,
    val: Value,
) !void {
    // Convertimos a su propio tipo para coherencia Value -> Payload
    const v = types.Variable{
        .type = val.t,
        .value = val.p,
    };

    // Insertar o actualizar sin cambiar la clave si existe
    const name_dup = try std.heap.page_allocator.dupe(u8, name);
    const gop = try vars.getOrPut(name_dup);
    if (!gop.found_existing) {
        gop.key_ptr.* = name_dup;
        gop.value_ptr.* = v;
    } else {
        // Ya existe: liberamos el duplicado que no usaremos
        std.heap.page_allocator.free(name_dup);
        gop.value_ptr.* = v;
    }
}

fn updateExistingVar(
    vars: *VarMap,
    name: []const u8,
    new_val: Value,
    declared_type: types.Type,
) !void {
    const entry = vars.getEntry(name) orelse return types.ParsingError.UndefinedVariable;
    // Convertimos al tipo declarado final
    const conv = convert(declared_type, new_val);
    entry.value_ptr.* = types.Variable{ .type = declared_type, .value = conv.p };
}

fn makeValueFromVar(v: types.Variable) Value {
    return Value{ .t = v.type, .p = v.value };
}

fn execStatement(
    tokens: []const types.Instruction,
    vars: *VarMap,
) !?Value {
    if (tokens.len == 0) return null;

    // Declaración de tipo: int x; int x = expr;
    if (tokens[0].type == .TypeDeclaration) {
        if (tokens.len < 2 or tokens[1].type != .Value or
            !isIdentifierToken(tokens[1]))
        {
            return types.ParsingError.MissingVariableName;
        }
        const t: types.Type = @enumFromInt(tokens[0].index);
        if (t == .void) return types.ParsingError.Type;

        const name = tokens[1].string;

        if (tokens.len == 2) {
            // int x;
            const def = defaultValue(t);
            var vv = def;
            vv.t = t;
            vv = convert(t, vv);
            try storeVar(vars, name, vv);
            return null;
        }

        if (tokens.len >= 3 and tokens[2].type == .Assignation and
            eql(tokens[2].string, "="))
        {
            const expr_tokens = tokens[3..];
            const v = try evalExpr(expr_tokens, vars);
            const cv = convert(t, v);
            try storeVar(vars, name, cv);
            return null;
        }

        return types.ParsingError.SyntaxError;
    }

    // Asignación: x = expr; x += expr; ...
    if (tokens.len >= 3 and tokens[0].type == .Value and
        isIdentifierToken(tokens[0]) and tokens[1].type == .Assignation)
    {
        const name = tokens[0].string;
        const var_ptr = vars.getEntry(name) orelse return types.ParsingError.UndefinedVariable;
        const decl_t = var_ptr.value_ptr.*.type;

        if (eql(tokens[1].string, "=")) {
            const r = try evalExpr(tokens[2..], vars);
            const rc = convert(decl_t, r);
            var_ptr.value_ptr.* = types.Variable{
                .type = decl_t,
                .value = rc.p,
            };
            return null;
        } else if (assignmentBinaryOp(tokens[1].string)) |bop| {
            const cur = makeValueFromVar(var_ptr.value_ptr.*);
            const r = try evalExpr(tokens[2..], vars);
            const applied = try applyBinary(bop, cur, r);
            const rc = convert(decl_t, applied);
            var_ptr.value_ptr.* = types.Variable{
                .type = decl_t,
                .value = rc.p,
            };
            return null;
        } else {
            return types.ParsingError.SyntaxError;
        }
    }

    // Si no es declaración ni asignación, es una expresión pura
    const res = try evalExpr(tokens, vars);
    return res;
}

pub fn exec(
    tokens: []const types.Instruction,
    vars: *VarMap,
) !?Value {
    return try execStatement(tokens, vars);
}

pub fn printValue(writer: anytype, v: Value) !void {
    switch (v.t) {
        .boolean => try writer.print("{s}", .{if (v.p.boolean) "true" else "false"}),
        .char => try writer.print("'{c}'", .{v.p.char}),
        .int => try writer.print("{}", .{v.p.int}),
        .long => try writer.print("{}", .{v.p.long}),
        .float => try writer.print("{d}", .{v.p.float}),
        .double => try writer.print("{d}", .{v.p.double}),
        .void => try writer.print("void", .{}),
    }
}
