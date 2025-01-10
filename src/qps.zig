const std = @import("std");

// Useful types
pub const Pattern8 = MakePatternType(8);
pub const Pattern16 = MakePatternType(16);
pub const Pattern32 = MakePatternType(32);
pub const Pattern64 = MakePatternType(64);
pub const Pattern128 = MakePatternType(128);
pub const Pattern256 = MakePatternType(256);

pub const ParseByteError = error{
    WildCard,
    BadSlice,
};

pub const PatternError = error{
    TooManyTokens,
    ParseError,
};

pub const SearchResult = error{
    NotFound,
    BadOperation,
};

pub const FileSearchError = error{
    NotFound,
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

pub fn MakeSearchRunner(pattern_size: usize) type {
    return struct {
        pattern_size: usize = pattern_size,
        pub fn search(self: *const @This(), haystack: []u8, scan_len: usize, needle: MakePatternType(pattern_size)) SearchResult!?usize {
            if (self.pattern_size != needle.size) {
                return SearchResult.BadOperation;
            }
            if (scan_len - pattern_size > haystack.len) {
                return SearchResult.BadOperation;
            }

            const mask_v: @Vector(pattern_size, u8) = needle.mask[0..pattern_size].*;
            const find: @Vector(pattern_size, u8) = needle.bytes[0..pattern_size].*;

            for (0..scan_len - pattern_size) |i| {

                // Don't bother with SIMD unless we find an initial byte
                // However now we will double-check each instance of the starting byte.
                // Slower on data where the pattern initial byte is very prevelent (~15+-% of all bytes).
                if (haystack[i] != needle.bytes[0]) {
                    continue;
                }

                const src: @Vector(pattern_size, u8) = haystack[i..][0..pattern_size].*;
                if (@reduce(.And, ((src ^ find) | mask_v) == mask_v)) {
                    return i;
                }
            }
            return SearchResult.NotFound;
        }

        pub fn search_no_wildcards(self: *const @This(), haystack: []u8, scan_len: usize, needle: MakePatternType(pattern_size)) SearchResult!?usize {
            if (self.pattern_size != needle.size) {
                return SearchResult.BadOperation;
            }
            if (scan_len - pattern_size > haystack.len) {
                return SearchResult.BadOperation;
            }

            const find: @Vector(pattern_size, u8) = needle.bytes[0..pattern_size].*;

            for (0..scan_len - pattern_size) |i| {

                // Don't bother with SIMD unless we find an initial byte
                // However now we will double-check each instance of the starting byte.
                // Slower on data where the pattern initial byte is very prevelent (~15+-% of all bytes).
                if (haystack[i] != needle.bytes[0]) {
                    continue;
                }

                const src: @Vector(pattern_size, u8) = haystack[i..][0..pattern_size].*;
                if (@reduce(.And, src == find)) {
                    return i;
                }
            }
            return SearchResult.NotFound;
        }
    };
}

pub fn MakeFileScan(pattern_size: usize, chunk_size: usize) type {
    return struct {
        pub fn find_pattern(allocator: std.mem.Allocator, file: std.fs.File, needle: MakePatternType(pattern_size)) !usize {
            const sr: MakeSearchRunner(pattern_size) = .{};

            const buf = try allocator.alloc(u8, chunk_size);
            defer allocator.free(buf);

            const fstat = try file.stat();
            if (fstat.size <= pattern_size) {
                unreachable;
            }
            //std.debug.print("[SZ: {d}]\n", .{fstat.size});

            var i: u64 = 0;
            var file_index: usize = 0;
            scan: while (file_index < fstat.size) {
                const end_idx: usize = if (file_index + chunk_size >= fstat.size) fstat.size - 1 else file_index + chunk_size; // must promize sz > 0

                // std.debug.print("[{d}] [range: {d}..{d}]\n", .{ i, file_index, end_idx });

                // Cant find a pattern in this region
                if (end_idx - file_index < pattern_size) {
                    break;
                }

                try file.seekTo(file_index);

                _ = try file.read(buf);

                // Perform operations on chunk
                const found: ?usize = sr.search(buf, chunk_size, needle) catch |err| found: {
                    if (err == SearchResult.BadOperation) {
                        //   std.debug.print("[scan error: Bad Operation]\n", .{});
                        break :scan;
                    }
                    //last iter
                    if (end_idx == fstat.size - 1) {
                        //    std.debug.print("[NOT FOUND]\n", .{});
                        break :scan;
                    }
                    break :found null;
                };

                // overlap sections by pattern size so we cannto miss patterns at the end of a block [(N - (pattern_sz - 1))..N]
                if (found == null) {
                    file_index += chunk_size;
                    file_index -= pattern_size;
                    i += 1;
                    continue;
                }
                //  std.debug.print("[FOUND AT: 0x{X}+0x{X} (0x{X})] ABS: 0x{X:0>8}\n", .{ file_index, found.?, file_index + found.?, file_index + found.? });
                return file_index + found.?;
            }
            return FileSearchError.NotFound;
        }
    };
}
