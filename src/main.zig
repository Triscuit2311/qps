const std = @import("std");
const qps = @import("qps.zig");

pub fn main() anyerror!void {
    const hex = "ee0f85d9feffffe9f4feffff488b5b084883c3c8eb39662e0f1f840000000000488d4318498b4ef048894810410f1046e00f11006641c746e00000498b46f848";
    var patty: qps.Pattern64 = .{};
    try patty.init(hex, std.io.getStdOut().writer());

    var args = std.process.args();
    _ = args.next();
    const file_path = args.next().?;

    const file = std.fs.cwd().openFile(file_path, .{ .mode = std.fs.File.OpenMode.read_only }) catch |err| {
        std.log.err("Failed to open file: {s}", .{@errorName(err)});
        return;
    };
    defer file.close();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const ally = gpa.allocator();
    defer {
        const ds = gpa.deinit();
        if (ds == .leak) undefined;
    }

    const scan = qps.MakeFileScan(64, 1024 * 10);
    const found: usize = try scan.find_pattern(ally, file, patty);

    std.debug.print("Found at: +0x{X}\n", .{found});
}
