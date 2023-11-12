const std = @import("std");

const instruction = @import("instruction.zig");
const mov = @import("mov.zig");

const Args = struct {
    file_path: []const u8,

    fn parse() !Args {
        var argsIter = std.process.args();
        defer argsIter.deinit();

        _ = argsIter.skip();
        const file_path = argsIter.next() orelse return error.FileNameMissing;
        return Args{ .file_path = file_path };
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);

    const args = try Args.parse();
    try decode(args);
}

fn decode(args: Args) !void {
    const file = try std.fs.cwd().openFile(args.file_path, .{});

    var buffered_writer = std.io.bufferedWriter(std.io.getStdOut().writer());
    var writer = buffered_writer.writer();

    while (file.reader().readBytesNoEof(2)) |bytes| {
        if (mov.RegisterRegister.isOpCode(bytes[0])) {
            var inst = instruction.MovRegisterRegister.init(bytes);
            try inst.key_data.decode(writer);
        } else return error.AA;
    } else |err| {
        if (err != error.EndOfStream) return err;
    }

    try buffered_writer.flush();
}
