//! The one-page gallery: the committed page shell with a card per icon.
const std = @import("std");
const svg = @import("svg.zig");
const emit = @import("emit.zig");
const template = @import("template.zig");

const shell = @embedFile("gallery.html");

pub fn page(allocator: std.mem.Allocator, icons: []const svg.Icon) ![]const u8 {
    std.debug.assert(icons.len > 0);

    var cards: std.Io.Writer.Allocating = .init(allocator);
    defer cards.deinit();

    for (icons) |icon| {
        try cards.writer.print(
            "\n      <button class=\"icon-card\" type=\"button\" data-name=\"{s}\" aria-label=\"Copy {s}\">\n" ++
                "        <span class=\"icon-preview\" aria-hidden=\"true\">\n" ++
                "          <svg viewBox=\"" ++ emit.view_box ++ "\" fill=\"none\">{s}</svg>\n" ++
                "        </span>\n" ++
                "        <span class=\"icon-name\">{s}</span>\n" ++
                "        <span class=\"copy-state\" aria-hidden=\"true\">Copy</span>\n" ++
                "      </button>",
            .{ icon.name, icon.name, icon.body, icon.name },
        );
    }

    var count_buffer: [16]u8 = undefined;
    const count = try std.fmt.bufPrint(&count_buffer, "{d}", .{icons.len});
    const with_count = try template.fill(allocator, shell, "{{COUNT}}", count);
    defer allocator.free(with_count);
    const out = try template.fill(allocator, with_count, "{{CARDS}}", cards.written());

    std.debug.assert(std.mem.indexOf(u8, out, "{{") == null);

    return out;
}

test "the page carries one card per icon and the count twice" {
    const icons = [_]svg.Icon{
        .{ .name = "a", .file = "a.svg", .source = "", .body = "<g/>" },
        .{ .name = "b", .file = "b.svg", .source = "", .body = "<g/>" },
    };
    const out = try page(std.testing.allocator, &icons);
    defer std.testing.allocator.free(out);
    try std.testing.expectEqual(@as(usize, 2), std.mem.count(u8, out, "class=\"icon-card\""));
    try std.testing.expect(std.mem.indexOf(u8, out, "<span id=\"visible-count\">2</span> of 2 UI icons") != null);
}
