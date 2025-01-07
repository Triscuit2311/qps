const std = @import("std");

// Useful types
pub const Pattern8 = MakePatternType(8);
pub const Pattern32 = MakePatternType(32);
pub const Pattern64 = MakePatternType(64);
pub const Pattern128 = MakePatternType(128);
pub const Pattern256 = MakePatternType(256);

const ParseByteError = error{
    WildCard,
    BadSlice,
};

fn parseByte(val: []const u8) ParseByteError!u8 {
    if (val.len > 2) {
        return ParseByteError.BadSlice;
    }

    return std.fmt.parseUnsigned(u8, val, 16) catch |err| {
        switch (err) {
            std.fmt.ParseIntError.Overflow => {
                return ParseByteError.BadSlice;
            },
            std.fmt.ParseIntError.InvalidCharacter => {
                return ParseByteError.WildCard;
            },
        }
    };
}

const PatternError = error{
    TooManyTokens,
    ParseError,
};

pub fn MakePatternType(sz: usize) type {
    return struct {
        size: usize = sz,
        use_mask: bool = false,
        bytes: [sz]u8 = [_]u8{0x0} ** sz,
        mask: [sz]u8 = [_]u8{0x0} ** sz,

        pub fn print(self: *@This(), w: anytype) anyerror!void {
            _ = try w.print("Pattern{d} {{", .{self.size});

            _ = try w.write("bytes[");
            for (self.bytes, 0..) |b, i| {
                if (i >= self.size) {
                    break;
                }
                _ = try w.print("0x{X:0>2}", .{b});
                if (i < self.size - 1) {
                    _ = try w.write(", ");
                } else {
                    break;
                }
            }
            _ = try w.write("] ");

            _ = try w.write("mask[");
            for (self.mask, 0..) |b, i| {
                if (i >= self.size) {
                    break;
                }
                _ = try w.print("0x{X:0>2}", .{b});

                if (i < self.size - 1) {
                    _ = try w.write(", ");
                } else {
                    break;
                }
            }
            _ = try w.write("] ");

            _ = try w.write("}");
        }

        pub fn printCombined(self: *@This(), w: anytype) anyerror!void {
            _ = try w.print("Pattern{d} {{", .{self.size});

            _ = try w.write("bytes[");
            for (self.bytes, 0..) |b, i| {
                if (i >= self.size) {
                    break;
                }
                _ = try w.print("0x{X:0>2}{s}", .{ b, if (self.mask[i] != 0) "*" else "" });
                if (i < self.size - 1) {
                    _ = try w.write(", ");
                } else {
                    break;
                }
            }
            _ = try w.write("]");

            _ = try w.write("}");
        }

        fn parseInto(self: *@This(), input: []const u8, ct: *usize) PatternError!void {
            var len: usize = 0;
            var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
            defer arena.deinit();
            const allocator = arena.allocator();

            var clean = allocator.alloc(u8, input.len) catch {
                return PatternError.ParseError;
            };

            // Since output array is set to input length, must _maintain_ size.

            const remove = [_][]const u8{
                "\r\n",
                "\n",
                "\\x",
                "0x",
                ",",
                "%",
                ";",
                ":",
            };
            const replace = [_][]const u8{
                " ",
                "  ",
                "   ",
            };

            // remove leading 0x to simplify formatting on pure hex patterns
            std.mem.copyForwards(u8, clean, input);

            for (remove) |v| {
                _ = std.mem.replace(u8, clean, v, replace[v.len - 1], clean);
            }

            //TODO maybe move this up
            // see if we have no delims
            const has_delims: bool = v: {
                for (2..clean.len) |i| {
                    switch (clean[i]) {
                        ' ' => break :v true,
                        else => {},
                    }
                } else {
                    break :v false;
                }
            };

            // if no delims, add space delimiting
            if (!has_delims) {
                const clean_nd = allocator.alloc(u8, input.len * 2) catch {
                    return PatternError.ParseError;
                };

                var c_i: usize = 0;
                var o_i: usize = 0;
                while (c_i < clean_nd.len) : (c_i += 3) {
                    if (o_i >= clean.len) {
                        break;
                    }
                    clean_nd[c_i] = clean[o_i];
                    o_i += 1;
                    if (o_i >= clean.len) {
                        break;
                    }
                    clean_nd[c_i + 1] = clean[o_i];
                    o_i += 1;
                    clean_nd[c_i + 2] = ' ';
                }

                // pad with spaces
                while (c_i < clean_nd.len) : (c_i += 1) {
                    clean_nd[c_i] = ' ';
                }

                clean = allocator.alloc(u8, input.len * 2) catch {
                    return PatternError.ParseError;
                };
                @memcpy(clean, clean_nd);
            }

            var it = std.mem.tokenizeAny(u8, clean, " ");

            len = 0;
            ct.* = 0;
            while (it.next()) |v| {
                if (len >= self.size) {
                    return PatternError.TooManyTokens;
                }

                // track failure point
                ct.* = it.index - v.len + 1;

                self.bytes[len], self.mask[len] = res: {
                    if (parseByte(v)) |b| {
                        break :res .{ b, 0x00 };
                    } else |err| {
                        switch (err) {
                            ParseByteError.WildCard => {
                                break :res .{ @as(u8, 0xFF), 0xFF };
                            },
                            ParseByteError.BadSlice => {
                                return PatternError.ParseError;
                            },
                        }
                    }
                };

                len += 1;
            }

            // backfill wildcards
            while (len < self.size) {
                self.bytes[len], self.mask[len] = .{ 0x00, 0xFF };
                len += 1;
            }
        }

        pub fn init(self: *@This(), input: []const u8, out: anytype) anyerror!void {
            var ct: usize = 0;
            self.parseInto(input, &ct) catch |err| {
                switch (err) {
                    PatternError.TooManyTokens => {
                        _ = try out.print("Error: {}\n", .{err});
                    },
                    PatternError.ParseError => {
                        _ = try out.print("Error: {}\n{s:>10} | ", .{ err, "Input" });
                        for (0..ct) |_| {
                            _ = try out.write(" ");
                        }
                        _ = try out.write("^\n");
                    },
                }
                return err;
            };
        }
    };
}

//Tests

// Only for test usage
fn checkArrAgainstPatternResult(check: []const u8, pattern: []const u8) bool {
    if (check.len != pattern.len) {
        return false;
    }
    return std.mem.eql(u8, check, pattern);
}

test "parse_errors" {
    std.testing.log_level = .info;

    var p: MakePatternType(8) = .{};

    const input_toolong = "0x00, 0x01, 0x02, 0x03, 0xFF, 0xFE, 0xFD, 0xFC, 0x99"; // One too many

    try std.testing.expectError(PatternError.TooManyTokens, p.init(input_toolong, std.io.null_writer));

    const input_badtoken0 = "0x00, 0x01, 0x02, 0x03, 0xFFFFFF, 0xFE, 0xFD, 0xFC"; // too large
    // We do not want an overflow
    try std.testing.expectError(PatternError.ParseError, p.init(input_badtoken0, std.io.null_writer));
}

test "parse_success" {
    var p: MakePatternType(8) = .{};

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
