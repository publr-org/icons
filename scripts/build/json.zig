//! JSON string escaping with the same output as JavaScript's JSON.stringify, so
//! the generated adapters stay byte-identical to the ones the node scripts made:
//! quotes, backslashes and the five short escapes; other control bytes as
//! lowercase \u00xx; everything else, non-ASCII included, verbatim.
const std = @import("std");

pub fn write_string(writer: *std.Io.Writer, text: []const u8) !void {
    try writer.writeByte('"');

    for (text) |byte| {
        switch (byte) {
            '"' => try writer.writeAll("\\\""),
            '\\' => try writer.writeAll("\\\\"),
            0x08 => try writer.writeAll("\\b"),
            0x0c => try writer.writeAll("\\f"),
            '\n' => try writer.writeAll("\\n"),
            '\r' => try writer.writeAll("\\r"),
            '\t' => try writer.writeAll("\\t"),
            0...0x07, 0x0b, 0x0e...0x1f => try writer.print("\\u{x:0>4}", .{byte}),
            else => try writer.writeByte(byte),
        }
    }

    try writer.writeByte('"');
}

test "escapes like JSON.stringify" {
    var out: std.Io.Writer.Allocating = .init(std.testing.allocator);
    defer out.deinit();

    try write_string(&out.writer, "a\"b\\c\nd\te\x01f\u{e9}");
    try std.testing.expectEqualStrings("\"a\\\"b\\\\c\\nd\\te\\u0001f\u{e9}\"", out.written());
}
