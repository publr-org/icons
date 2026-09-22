pub fn get(name: Name) []const u8 {
    const values = comptime blk: {
        const fields = @typeInfo(Name).@"enum".fields;
        var result: [fields.len][]const u8 = undefined;
        for (fields, 0..) |field, index| result[index] = @field(@This(), field.name);
        break :blk result;
    };
    return values[@intFromEnum(name)];
}

/// The icon's name as the sprite id spells it: `calendar_check` → `calendar-check`.
pub fn kebab(comptime snake: []const u8) *const [snake.len]u8 {
    comptime {
        @setEvalBranchQuota(20000);
        var out: [snake.len]u8 = undefined;
        for (snake, 0..) |c, i| out[i] = if (c == '_') '-' else c;
        const frozen = out;
        return &frozen;
    }
}

/// One `<symbol>` for the page's sprite. Captures are capitalized because
/// every lowercase identifier here may be an icon.
pub fn writeSymbol(writer: anytype, name: Name) !void {
    switch (name) {
        inline else => |Icon| try writer.print("<symbol id=\"publr-icon-{s}\" viewBox=\"{s}\" fill=\"none\">{s}</symbol>", .{ kebab(@tagName(Icon)), view_box, get(Icon) }),
    }
}

/// The hidden sprite holding the given icons, the way a server writes it into a page.
pub fn writeSprite(writer: anytype, names: []const Name) !void {
    try writer.writeAll("<svg id=\"publr-icon-sprite\" style=\"display:none\" aria-hidden=\"true\">");
    for (names) |name| try writeSymbol(writer, name);
    try writer.writeAll("</svg>");
}
