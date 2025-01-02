const std = @import("std");
const pattern = @import("pattern.zig");
const search = @import("search.zig");

pub fn main() anyerror!void {
    const cout = std.io.getStdOut().writer();

    const input = "DE ?? BE EF";

    var p: pattern.Pattern8 = .{};

    try p.init(input, cout);
    try p.print(cout);
    try p.printCombined(cout);

    std.debug.print("\n", .{});

    _ = search.MakeSearchRunner(123);
}
