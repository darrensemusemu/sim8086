const std = @import("std");

const instruction = @import("instruction.zig");

pub const RegisterRegister = packed struct {
    rm: u3,
    reg: u3,
    mod: u2,
    w: u1,
    d: u1,
    op_code: u6,

    pub const op_code: u8 = 0b1000_1000;

    pub fn isOpCode(key_byte1: u8) bool {
        return key_byte1 & 0b1111_1100 == op_code;
    }

    pub fn decode(self: *RegisterRegister, writer: anytype) !void {
        var src: []const u8 = undefined;
        var dst: []const u8 = undefined;
        switch (self.mod) {
            0b00, 0b01, 0b10 => return error.MODBitsUnimplemented,
            0b11 => {
                if (self.d == 1) {
                    dst = regFiledEncoding(self.reg, self.w);
                    src = rmFiledEncoding(self.rm, self.mod, self.w);
                } else {
                    dst = rmFiledEncoding(self.rm, self.mod, self.w);
                    src = regFiledEncoding(self.reg, self.w);
                }
            },
        }

        try writer.print("mov {s} {s}\n", .{ dst, src });
    }
};

const regFieldEncodingMap = [_]struct {
    []const u8,
    []const u8,
}{
    .{ "al", "ax" },
    .{ "cl", "cx" },
    .{ "dl", "dx" },
    .{ "bl", "bx" },
    .{ "ah", "sp" },
    .{ "ch", "bp" },
    .{ "dh", "si" },
    .{ "bh", "di" },
};

fn regFiledEncoding(reg_bits: u3, w_bit: u1) []const u8 {
    if (w_bit == 0) {
        return regFieldEncodingMap[reg_bits][0];
    }
    return regFieldEncodingMap[reg_bits][1];
}

fn rmFiledEncoding(rm_bits: u3, mod_bits: u2, w_bit: u1) []const u8 {
    if (mod_bits != 0b11) {
        std.debug.panic("rm addr calulations not implemented", .{});
    }
    return regFiledEncoding(rm_bits, w_bit);
}
