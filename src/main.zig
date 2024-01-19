const std = @import("std");

const instruction = @import("instruction.zig");
const mov = @import("mov.zig");

const Args = struct {
    action: enum { help, decode },
    file_path: ?[]const u8 = null,
    file_path2: ?[]const u8 = null,

    fn parse() !Args {
        var argsIter = std.process.args();
        defer argsIter.deinit();

        _ = argsIter.skip(); // prog name

        const action = argsIter.next() orelse return error.ArgActionMissing;
        var args = Args{ .action = .help, .file_path = null };
        if (std.mem.eql(u8, action, "decode")) {
            args.action = .decode;
            args.file_path = argsIter.next() orelse return error.FileNameMissing;
        }
        return args;
    }
};

pub fn main() !void {
    const args = try Args.parse();

    var std_out = std.io.getStdOut();
    var buffered_writer = std.io.bufferedWriter(std_out.writer());

    switch (args.action) {
        .decode => {
            var writer = buffered_writer.writer();
            try decode(writer, args);
            try buffered_writer.flush();
        },
        .help => {
            std.debug.print("TODO: help :)\n", .{});
        },
    }
}

fn decode(writer: anytype, args: Args) !void {
    const file = try std.fs.cwd().openFile(args.file_path.?, .{});

    try writer.writeAll("bits 16\n");
    var reader = file.reader();

    while (reader.readByte()) |byte| {
        if (mov.RegisterMemory.isOpCode(byte)) {
            try mov.RegisterMemory.decode(byte, reader, writer);
        } else if (mov.ImmediateToRegister.isOpCode(byte)) {
            try mov.ImmediateToRegister.decode(byte, reader, writer);
        } else return error.AA;
    } else |err| {
        if (err != error.EndOfStream) return err;
    }
}
