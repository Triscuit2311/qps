const std = @import("std");
const qps = @import("qps.zig");
const td = @import("test/test_data.zig");

test {
    _ = @import("test/simd.zig");
}
// Only for test usage
fn checkArrAgainstPatternResult(check: []const u8, pattern: []const u8) bool {
    if (check.len != pattern.len) {
        return false;
    }
    return std.mem.eql(u8, check, pattern);
}

test "parse_errors" {
    std.testing.log_level = .info;

    var p: qps.MakePatternType(8) = .{};

    const input_toolong = "0x00, 0x01, 0x02, 0x03, 0xFF, 0xFE, 0xFD, 0xFC, 0x99"; // One too many

    try std.testing.expectError(qps.PatternError.TooManyTokens, p.init(input_toolong, std.io.null_writer));

    const input_badtoken0 = "0x00, 0x01, 0x02, 0x03, 0xFFFFFF, 0xFE, 0xFD, 0xFC"; // too large
    // We do not want an overflow
    try std.testing.expectError(qps.PatternError.ParseError, p.init(input_badtoken0, std.io.null_writer));
}

test "parse_success" {
    var p: qps.MakePatternType(8) = .{};

    const check: [8]u8 = [8]u8{ 0x00, 0x01, 0x02, 0x03, 0xFF, 0xFE, 0xFD, 0xFC };

    const input_single = "0x00";
    p.init(input_single, std.io.null_writer) catch {
        try std.testing.expect(false);
    };

    const fmt_inputs = [_][]const u8{
        "0x00, 0x01, 0x02, 0x03, 0xFF, 0xFE, 0xFD, 0xFC",
        "0x00,0x01,0x02,0x03,0xFF,0xFE,0xFD,0xFC",
        "0x00 0x01 0x02 0x03 0xFF 0xFE 0xFD 0xFC",
        "00, 01, 02, 03, FF, FE, FD, FC",
        "00 01 02 03 FF FE FD FC",
        "00%01%02%03%ff%fe%fd%fc",
        "00,01,02,03,ff,fe,fd,fc",
        "00;01;02;03;ff;fe;fd;fc",
        "00:01:02:03:ff:fe:fd:fc",
        "00\n01\n02\n03\nff\nfe\nfd\nfc",
        "00\r\n01\r\n02\r\n03\r\nff\r\nfe\r\nfd\r\nfc",
        "\\x00\\x01\\x02\\x03\\xff\\xfe\\xfd\\xfc", // _escaped_ \x
        "00010203fffefdfc",
        "0x00010203fffefdfc",

        //"\x00\x01\x02\x03\xff\xfe\xfd\xfc", //not supported as a string parse, use raw bytes
    };

    for (fmt_inputs) |input| {
        errdefer std.log.err("Failed on string: {s}", .{input});
        p.init(input, std.io.null_writer) catch {
            try std.testing.expect(false);
        };
        try std.testing.expect(checkArrAgainstPatternResult(check[0..8], p.bytes[0..p.size]));
    }

    const mix_input = "0x00 01, 02; 03: 0xFF%FE\r\nfd\\xfc";
    {
        errdefer {
            std.log.err("\nFailed on string: {s}\n", .{mix_input});
            _ = p.print(std.io.getStdErr().writer()) catch {};
        }
        p.init(mix_input, std.io.null_writer) catch {
            try std.testing.expect(false);
        };
        try std.testing.expect(checkArrAgainstPatternResult(check[0..8], p.bytes[0..p.size]));
    }
}

test "search" {
    const cout = std.io.getStdOut().writer();

    const input = "0x74,0x69,0x2e,0x20,0x4e,0x75,0x6c,0x6c,0x61,0x20,0x76,0x65,0x6c,0x69,0x74,0x20,0x6f,0x72,0x63,0x69,0x2c,0x20,0x6c,0x61,0x63,0x69,0x6e,0x69,0x61,0x20,0x69,0x6e,";

    var p: qps.Pattern32 = .{};

    try p.init(input, cout);
    try p.printCombined(cout);

    std.debug.print("\n", .{});

    const s: qps.MakeSearchRunner(32) = .{};

    var data = [_]u8{0x0} ** 10000;

    td.GetData(10000, &data);

    var t = try std.time.Timer.start();
    const offset: ?usize = s.search(&data, data.len, p) catch |err| {
        switch (err) {
            qps.SearchResult.NotFound => {
                std.debug.print("Needle Not Found\n", .{});
            },
            qps.SearchResult.BadOperation => {
                std.debug.print("Bad Operation\n", .{});
            },
        }
        return;
    };
    const n: u64 = t.read();
    _ = offset.?;

    std.debug.print("Found in: {d}ns\n", .{n});
}
