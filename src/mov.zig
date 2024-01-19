const std = @import("std");

const instruction = @import("instruction.zig");

pub const RegisterMemory = packed struct {
    disp_hi: u8 = 0,
    disp_lo: u8 = 0,
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

    pub fn decode(first_byte: u8, reader: anytype, writer: anytype) !void {
        const second_byte = try reader.readByte();

        var y: u16 = @bitCast([2]u8{ second_byte, first_byte });
        const self: *RegisterMemory = @alignCast(@ptrCast(&y));

        var src: []const u8 = undefined;
        var dst: []const u8 = undefined;
        var buf: [50]u8 = undefined;

        var reg_value = self.regFiledEncoding(self.reg);
        var rm_value = try self.rmFiledEncoding(&buf, reader);

        if (self.d == 1) {
            dst = reg_value;
            src = rm_value;
        } else {
            dst = rm_value;
            src = reg_value;
        }

        try writer.print("mov {s}, {s}\n", .{ dst, src });
    }

    fn regFiledEncoding(self: *RegisterMemory, reg_bits: u3) []const u8 {
        if (self.w == 0) {
            return regFieldEncodingMap[reg_bits][0];
        }
        return regFieldEncodingMap[reg_bits][1];
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
            0b11 => return self.regFiledEncoding(self.rm),
        }

        if (disp == 0) {
            return try std.fmt.bufPrint(buf, "[{s}]", .{effective_addr});
        }
        return try std.fmt.bufPrint(buf, "[{s} + {d}]", .{ effective_addr, disp });
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
