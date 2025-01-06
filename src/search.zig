const std = @import("std");
const pattern = @import("pattern.zig");

pub const SearchResult = error{
    NotFound,
    BadOperation,
};

pub fn MakeSearchRunner(pattern_size: usize) type {
    return struct {
        pattern_size: usize = pattern_size,
        pub fn search(self: *const @This(), haystack: []u8, scan_len: usize, needle: pattern.MakePatternType(pattern_size)) SearchResult!usize {
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

        pub fn search_no_wildcards(self: *const @This(), haystack: []u8, scan_len: usize, needle: pattern.MakePatternType(pattern_size)) SearchResult!usize {
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
