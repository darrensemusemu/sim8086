const std = @import("std");

const instruction = @import("instruction.zig");

// pub const ImmediateToRegisterMemory = packed struct {
//     // data: u8 = 0,
//     // data: u8 = 0,
//     rm: u3,
//     _: u3 = 0,
//     mod: u2,
//     w: u1,
//     op_code: u7,
//
//     pub const op_code: u4 = 0b1011;
//
//     pub fn isOpCode(key_byte1: u8) bool {
//         std.debug.print(":b {b} \n", .{key_byte1});
//         return key_byte1 >> 4 == op_code;
//     }
//
//     pub fn decode(key_byte1: u8, reader: anytype, writer: anytype) !void {
//         _ = key_byte1;
//         _ = reader;
//         _ = writer;
//     }
// };

pub const ImmediateToRegister = packed struct {
    // data2: u8 = 0,
    // data: i8,
    reg: u3,
    w: u1,
    op_code: u4,

    pub const op_code: u4 = 0b1011;

    pub fn isOpCode(key_byte1: u8) bool {
        return key_byte1 >> 4 == op_code;
    }

    pub fn decode(key_byte1: u8, reader: anytype, writer: anytype) !void {
        const key_byte2 = try reader.readByte();
        var inst: u8 = @bitCast(key_byte1);
        const self: *ImmediateToRegister = @ptrCast(&inst);

        const dst = regFiledEncoding(self.w, self.reg);
        var src: u16 = key_byte2;
        if (self.w == 1) {
            const key_byte3 = try reader.readByte();
            src = @bitCast([_]u8{ key_byte2, key_byte3 });
        }

        try writer.print("mov {s}, {any}\n", .{ dst, src });
    }
};

pub const RegisterMemory = packed struct {
    // disp_hi: u8 = 0,
    // disp_lo: u8 = 0,
    rm: u3,
    reg: u3,
    mod: u2,
    w: u1,
    d: u1,
    op_code: u6,

    pub const op_code: u6 = 0b100010;

    pub fn isOpCode(key_byte1: u8) bool {
        return key_byte1 >> 2 == op_code;
    }

    pub fn decode(first_byte: u8, reader: anytype, writer: anytype) !void {
        const second_byte = try reader.readByte();
        var y: u16 = @bitCast([2]u8{ second_byte, first_byte });
        const self: *RegisterMemory = @ptrCast(&y);

        var buf: [50]u8 = undefined;
        var reg_value = regFiledEncoding(self.w, self.reg);
        var rm_value = try self.rmFiledEncoding(&buf, reader);

        if (self.d == 1) {
            try writer.print("mov {s}, {s}\n", .{ reg_value, rm_value });
        } else {
            try writer.print("mov {s}, {s}\n", .{ rm_value, reg_value });
        }
    }

    fn rmFiledEncoding(self: *RegisterMemory, buf: []u8, reader: anytype) ![]const u8 {
        var effective_addr: []const u8 = undefined;
        var disp: u16 = 0;
        switch (self.mod) {
            0b00 => {
                effective_addr = rmFieldEncodingMap[self.rm];
            },
            0b01 => {
                effective_addr = rmFieldEncodingMap[self.rm];
                disp = @intCast(try reader.readByte());
            },
            0b10 => {
                effective_addr = rmFieldEncodingMap[self.rm];
                disp = @bitCast(try reader.readBytesNoEof(2));
            },
            0b11 => return regFiledEncoding(self.w, self.rm),
        }

        if (disp == 0) {
            return try std.fmt.bufPrint(buf, "[{s}]", .{effective_addr});
        }
        return try std.fmt.bufPrint(buf, "[{s} + {d}]", .{ effective_addr, disp });
    }
};

fn regFiledEncoding(w_bit: u1, reg_bits: u3) []const u8 {
    if (w_bit == 0) {
        return regFieldEncodingMap[reg_bits][0];
    }
    return regFieldEncodingMap[reg_bits][1];
}

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

var rmFieldEncodingMap = [8][:0]const u8{
    "bx + si",
    "bx + di",
    "bp + si",
    "bp + di",
    "si",
    "di",
    "bp",
    "bx",
};
