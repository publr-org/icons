//! Splicing a value into a page shell wherever a `{{MARKER}}` appears.
const std = @import("std");

pub fn fill(allocator: std.mem.Allocator, text: []const u8, marker: []const u8, value: []const u8) ![]const u8 {
    std.debug.assert(marker.len > 0);
    std.debug.assert(std.mem.indexOf(u8, text, marker) != null);

    var out: std.Io.Writer.Allocating = .init(allocator);
    errdefer out.deinit();
    var rest = text;

    while (std.mem.indexOf(u8, rest, marker)) |at| {
        try out.writer.writeAll(rest[0..at]);
        try out.writer.writeAll(value);
        rest = rest[at + marker.len ..];
    }

    try out.writer.writeAll(rest);

    return out.toOwnedSlice();
}

test "every occurrence is replaced" {
    const out = try fill(std.testing.allocator, "a {{X}} b {{X}}", "{{X}}", "1");
    defer std.testing.allocator.free(out);
    try std.testing.expectEqualStrings("a 1 b 1", out);
}
