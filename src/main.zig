const std = @import("std");
const pattern = @import("pattern.zig");
const search = @import("search.zig");

pub fn main() anyerror!void {
    var args = std.process.args();
    var i: u8 = 0;
    while (args.next()) |a| {
        std.debug.print("[{d}] \"{s}\"\n", .{ i, a });
        i += 1;
    }
    std.debug.print("\n\n", .{});

    // const of = std.fs.File.OpenFlags{ .mode = std.fs.File.OpenMode.read_only, .lock = std.fs.File.Lock.shared };

    const file = std.fs.cwd().openFile("build.zig", .{ .mode = std.fs.File.OpenMode.read_only }) catch |err| {
        std.log.err("Failed to open file: {s}", .{@errorName(err)});
        return;
    };
    defer file.close();

    //   file.readToEndAlloc(allocator: Allocator, max_bytes: usize)

}
