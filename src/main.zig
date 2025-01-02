const std = @import("std");
const pattern = @import("pattern.zig");
const search = @import("search.zig");
const td = @import("tests/test_data.zig");

pub fn main() anyerror!void {
    const cout = std.io.getStdOut().writer();

    const input = "0x74,0x69,0x2e,0x20,0x4e,0x75,0x6c,0x6c,0x61,0x20,0x76,0x65,0x6c,0x69,0x74,0x20,0x6f,0x72,0x63,0x69,0x2c,0x20,0x6c,0x61,0x63,0x69,0x6e,0x69,0x61,0x20,0x69,0x6e,0x20,0x61,0x6e,0x74,0x65,0x20,0x69,0x64,0x2c,0x20,0x63,0x6f,0x6e,0x76";

    var p: pattern.Pattern64 = .{};

    try p.init(input, cout);
    try p.printCombined(cout);

    std.debug.print("\n", .{});

    const s: search.MakeSearchRunner(64) = .{};

    var data = [_]u8{0x0} ** 10000;

    td.GetData(10000, &data);

    var t = try std.time.Timer.start();
    const offset: usize = s.search(&data, data.len, p) catch |err| {
        switch (err) {
            search.SearchResult.NotFound => {
                std.debug.print("Needle Not Found\n", .{});
            },
            search.SearchResult.BadOperation => {
                std.debug.print("Bad Operation\n", .{});
            },
        }
        return;
    };
    const n: u64 = t.read();
    _ = offset;

    std.debug.print("Found in: {d}ns\n", .{n});
}
