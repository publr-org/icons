//! The offline Figma plugin: the committed plugin code with the icon list
//! embedded as JSON, each entry carrying the SVG file exactly as written.
const std = @import("std");
const svg = @import("svg.zig");
const json = @import("json.zig");
const template = @import("template.zig");

const code = @embedFile("figma.js");

pub fn plugin(allocator: std.mem.Allocator, icons: []const svg.Icon) ![]const u8 {
    std.debug.assert(icons.len > 0);

    var list: std.Io.Writer.Allocating = .init(allocator);
    defer list.deinit();
    const writer = &list.writer;

    try writer.writeByte('[');

    for (icons, 0..) |icon, index| {
        if (index > 0) {
            try writer.writeByte(',');
        }

        try writer.writeAll("{\"name\":");
        try json.write_string(writer, icon.name);
        try writer.writeAll(",\"svg\":");
        try json.write_string(writer, icon.source);
        try writer.writeByte('}');
    }

    try writer.writeByte(']');

    const out = try template.fill(allocator, code, "{{ICONS}}", list.written());

    std.debug.assert(std.mem.indexOf(u8, out, "{{") == null);

    return out;
}

test "the plugin embeds every icon's full source as JSON" {
    const icons = [_]svg.Icon{
        .{ .name = "a", .file = "a.svg", .source = "<svg>\n</svg>\n", .body = "" },
    };
    const out = try plugin(std.testing.allocator, &icons);
    defer std.testing.allocator.free(out);
    try std.testing.expect(std.mem.indexOf(u8, out, "const ICONS = [{\"name\":\"a\",\"svg\":\"<svg>\\n</svg>\\n\"}];") != null);
}
