const std = @import("std");
const op_code: u8 = 0b100010;

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

pub fn decode(writer: anytype, bytes: [2]u8) !void {
    const d_bit: u1 = @truncate((bytes[0] >> 1) & 0b1);
    const w_bit: u1 = @truncate(bytes[0] & 0b1);
    const mod_bits: u2 = @truncate(bytes[1] >> 6);
    const reg_bits: u3 = @truncate((bytes[1] >> 3) & 0b111);
    const rm_bits: u3 = @truncate(bytes[1] & 0b111);

    var src: []const u8 = undefined;
    var dst: []const u8 = undefined;
    switch (mod_bits) {
        0b00, 0b01, 0b10 => return error.MODBitsUnimplemented,
        0b11 => {
            if (d_bit == 1) {
                dst = regFiledEncoding(reg_bits, w_bit);
                src = rmFiledEncoding(rm_bits, mod_bits, w_bit);
            } else {
                dst = rmFiledEncoding(rm_bits, mod_bits, w_bit);
                src = regFiledEncoding(reg_bits, w_bit);
            }
        },
    }

    try writer.print("mov {s} {s}\n", .{ dst, src });
}

pub fn isMOV(op: u8) bool {
    return op >> 2 == op_code;
}

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
