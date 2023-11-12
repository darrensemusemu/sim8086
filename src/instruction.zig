const std = @import("std");
const mov = @import("mov.zig");

pub const MovRegisterRegister = Instruction(mov.RegisterRegister);

pub fn Instruction(comptime T: type) type {
    return struct {
        key_data: *T,

        const Self = @This();

        pub fn init(key_bytes: [2]u8) Self {
            var y: u16 = @bitCast([2]u8{ key_bytes[1], key_bytes[0] });
            return Self{
                .key_data = @alignCast(@ptrCast(&y)),
            };
        }
    };
}
