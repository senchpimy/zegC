const std = @import("std");

pub const Payload = union(Type) { int: i32, char: u8, long: i64, boolean: bool, void: u8, double: f64, float: f32 };
pub const Type = enum { int, char, long, boolean, void, double, float };
pub const Variable = struct { type: Type, value: Payload };
