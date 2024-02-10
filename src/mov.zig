const std = @import("std");

pub const AccumlatorToMemory = packed struct {
    //addr_hi: u8,
    //addr_lo: u8,
    w: u1,
    op_code: u7,

    pub const op_code: u7 = 0b1010001;

    pub fn isOpCode(key_byte1: u8) bool {
        return key_byte1 >> 1 == op_code;
    }

    pub fn decode(key_byte1: u8, reader: anytype, writer: anytype) !void {
        const inst: *const @This() = @ptrCast(&key_byte1);

        const src_byte: u8 = try reader.readByte();
        var src_word: ?u16 = null;
        if (inst.w == 1) {
            src_word = @bitCast([_]u8{ src_byte, try reader.readByte() });
        }

        try writer.print("mov [{d}], ax\n", .{src_word orelse src_byte});
    }
};

pub const MemoryToAccumlator = packed struct {
    //addr_hi: u8,
    //addr_lo: u8,
    w: u1,
    op_code: u7,

    pub const op_code: u7 = 0b1010000;

    pub fn isOpCode(key_byte1: u8) bool {
        return key_byte1 >> 1 == op_code;
    }

    pub fn decode(key_byte1: u8, reader: anytype, writer: anytype) !void {
        const inst: *const @This() = @ptrCast(&key_byte1);

        const src_byte: u8 = try reader.readByte();
        var src_word: ?u16 = null;
        if (inst.w == 1) {
            src_word = @bitCast([_]u8{ src_byte, try reader.readByte() });
        }

        try writer.print("mov ax, [{d}]\n", .{src_word orelse src_byte});
    }
};

pub const ImmediateToRegisterMemory = packed struct {
    // data2: u8 = 0,
    // data: u8 = 0,
    // disp hi
    // disp low
    rm: u3,
    _: u3 = 0,
    mod: u2,
    w: u1,
    op_code: u7,

    pub const op_code: u7 = 0b1100011;

    pub fn isOpCode(key_byte1: u8) bool {
        return key_byte1 >> 1 == op_code; // TODO: can do some along the lines of @bitSizeOf(@TypeOf(op_code))} - 8
    }

    pub fn decode(key_byte1: u8, reader: anytype, writer: anytype) !void {
        const key_byte2 = try reader.readByte();

        var inst_value: u16 = @bitCast([2]u8{ key_byte2, key_byte1 });
        const inst: *@This() = @ptrCast(&inst_value);

        var buf: [50]u8 = undefined;
        const dst = try rmFiledEncoding(inst, &buf, reader);

        var src_keyword: ?[]const u8 = null;
        if (inst.mod != 0b11) { // is mem mod
            src_keyword = if (inst.w == 1) "word" else "byte";
        }

        const src_byte: u8 = try reader.readByte();
        var src_word: ?u16 = null;
        if (inst.w == 1) {
            src_word = @bitCast([_]u8{ src_byte, try reader.readByte() });
        }

        try writer.print("mov {s}, {?s} {d}\n", .{
            dst,
            src_keyword orelse "",
            src_word orelse src_byte,
        });
    }
};

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
        const inst: *@This() = @ptrCast(@constCast(&key_byte1));

        const dst = regFiledEncoding(inst.w, inst.reg);
        var src: u16 = key_byte2;
        if (inst.w == 1) {
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
        var inst_value: u16 = @bitCast([2]u8{ second_byte, first_byte });
        const inst: *@This() = @ptrCast(&inst_value);

        var buf: [50]u8 = undefined;
        const reg_value = regFiledEncoding(inst.w, inst.reg);
        const rm_value = try rmFiledEncoding(inst, &buf, reader);

        if (inst.d == 1) {
            try writer.print("mov {s}, {s}\n", .{ reg_value, rm_value });
        } else {
            try writer.print("mov {s}, {s}\n", .{ rm_value, reg_value });
        }
    }
};

/// anytype  should have mod / rm / w bits set
fn rmFiledEncoding(inst: anytype, buf: []u8, reader: anytype) ![]const u8 {
    var effective_addr: []const u8 = undefined;
    switch (inst.mod) {
        0b00 => {
            if (inst.rm == 0b110) {
                const disp: i16 = @bitCast(try reader.readBytesNoEof(2));
                return try std.fmt.bufPrint(buf, "[{d}]", .{disp});
            }
            effective_addr = rmFieldEncodingMap[inst.rm];
            return try std.fmt.bufPrint(buf, "[{s}]", .{effective_addr});
        },
        0b01 => {
            effective_addr = rmFieldEncodingMap[inst.rm];
            const disp: i8 = @bitCast(try reader.readByte());
            return try std.fmt.bufPrint(buf, "[{s} + {d}]", .{ effective_addr, disp });
        },
        0b10 => {
            effective_addr = rmFieldEncodingMap[inst.rm];
            const disp: i16 = @bitCast(try reader.readBytesNoEof(2));
            return try std.fmt.bufPrint(buf, "[{s} + {d}]", .{ effective_addr, disp });
        },
        0b11 => return regFiledEncoding(inst.w, inst.rm),
    }
}

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
