const std = @import("std");

const MOV = @import("MOV.zig");

const Args = struct {
    file_path: []const u8,

    fn parse(alloc: std.mem.Allocator) !Args {
        var argsIter = try std.process.argsWithAllocator(alloc);
        defer argsIter.deinit();
        _ = argsIter.skip();
        const file_path = argsIter.next() orelse return error.FileNameMissing;
        return Args{ .file_path = file_path };
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);
    const alloc = gpa.allocator();
    const args = try Args.parse(alloc);
    try run(alloc, args);
}

fn run(alloc: std.mem.Allocator, args: Args) !void {
    const file = try std.fs.cwd().openFile(args.file_path, .{});
    var string = std.ArrayList(u8).init(alloc);
    defer string.deinit();

    var buffered_writer = std.io.bufferedWriter(std.io.getStdOut().writer());
    var writer = buffered_writer.writer();

    while (file.reader().readBytesNoEof(2)) |buf| {
        if (MOV.isMOV(buf[0])) {
            try MOV.decode(writer, buf);
        }
    } else |err| {
        if (err != error.EndOfStream) return err;
    }

    try buffered_writer.flush();
}
