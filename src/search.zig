const std = @import("std");
const pattern = @import("pattern.zig");

pub fn MakeSearchRunner(pattern_size: usize) type {
    return struct {
        pattern_size: usize = pattern_size,
    };
}
