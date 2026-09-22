//! One icon: its kebab-case name, the SVG file as written, and the markup inside
//! the root element. Reading validates the contract every icon must keep: a
//! lowercase kebab-case filename, no social brands, exactly one non-empty 24x24
//! root, and currentColor instead of a hardcoded black.
const std = @import("std");

pub const Icon = struct {
    name: []const u8,
    file: []const u8,
    /// The whole file, as the Figma plugin embeds it.
    source: []const u8,
    /// The root element's children, trimmed; CRLF normalised to LF.
    body: []const u8,
};

pub const Problem = error{
    NotKebabCase,
    SocialBrand,
    NoRoot,
    WrongViewBox,
    HardcodedBlack,
};

const social_names = [_][]const u8{
    "bluesky",  "facebook", "github",  "instagram", "linkedin",
    "mastodon", "tiktok",   "twitter", "x",         "youtube",
};

const black_values = [_][]const u8{ "black", "#000", "#000000" };
const whitespace = " \t\n\r\x0b\x0c";

/// Parses one icon file. `name` and `file` are borrowed; `body` is owned by
/// `allocator` only when the source contained CRLF, otherwise it borrows too.
pub fn read(allocator: std.mem.Allocator, file: []const u8, source: []const u8) !Icon {
    std.debug.assert(std.mem.endsWith(u8, file, ".svg"));
    std.debug.assert(file.len > ".svg".len);

    const name = file[0 .. file.len - ".svg".len];

    if (!is_kebab_case(name)) {
        return error.NotKebabCase;
    }

    for (social_names) |social| {
        if (std.mem.eql(u8, social, name)) {
            return error.SocialBrand;
        }
    }

    const root = find_root(source) orelse return error.NoRoot;
    const inner = std.mem.trim(u8, root.inner, whitespace);

    if (inner.len == 0) {
        return error.NoRoot;
    }

    if (!has_view_box(root.attributes, "0 0 24 24")) {
        return error.WrongViewBox;
    }

    if (has_hardcoded_black(inner)) {
        return error.HardcodedBlack;
    }

    const body = try normalise_newlines(allocator, inner);

    return .{ .name = name, .file = file, .source = source, .body = body };
}

fn is_kebab_case(name: []const u8) bool {
    if (name.len == 0) {
        return false;
    }

    var previous_dash = true;

    for (name) |byte| {
        const lower = byte >= 'a' and byte <= 'z';
        const digit = byte >= '0' and byte <= '9';

        if (byte == '-') {
            if (previous_dash) {
                return false;
            }

            previous_dash = true;
        } else if (lower or digit) {
            previous_dash = false;
        } else {
            return false;
        }
    }

    return !previous_dash;
}

const Root = struct { attributes: []const u8, inner: []const u8 };

/// The first `<svg ...>` element and what it wraps, matched case-insensitively.
fn find_root(source: []const u8) ?Root {
    const open_at = index_of_ignore_case(source, 0, "<svg") orelse return null;
    const after_tag = open_at + "<svg".len;

    if (after_tag < source.len and is_word_byte(source[after_tag])) {
        return null;
    }

    const close_at = std.mem.indexOfScalarPos(u8, source, after_tag, '>') orelse return null;
    const end_at = index_of_ignore_case(source, close_at + 1, "</svg>") orelse return null;

    std.debug.assert(end_at >= close_at + 1);

    return .{ .attributes = source[after_tag..close_at], .inner = source[close_at + 1 .. end_at] };
}

fn has_view_box(attributes: []const u8, expected: []const u8) bool {
    const at = index_of_ignore_case(attributes, 0, "viewbox=") orelse return false;
    const value = quoted_value(attributes[at + "viewbox=".len ..]) orelse return false;

    return std.mem.eql(u8, value, expected);
}

/// `stroke="black"`, `fill='#000'` and friends anywhere in the body, matching
/// the node script's word-boundary rule: the attribute name must not continue
/// a longer identifier.
fn has_hardcoded_black(body: []const u8) bool {
    var position: usize = 0;

    while (position < body.len) {
        const next = next_color_attribute(body, position) orelse return false;
        position = next.value_at;
        const value = quoted_value(body[next.value_at..]) orelse continue;

        for (black_values) |black| {
            if (std.ascii.eqlIgnoreCase(value, black)) {
                return true;
            }
        }
    }

    return false;
}

const ColorAttribute = struct { value_at: usize };

fn next_color_attribute(body: []const u8, from: usize) ?ColorAttribute {
    var best: ?usize = null;

    for ([_][]const u8{ "stroke=", "fill=" }) |attribute| {
        var search = from;

        while (index_of_ignore_case(body, search, attribute)) |at| {
            const bounded = at == 0 or !is_word_byte(body[at - 1]);

            if (bounded) {
                const value_at = at + attribute.len;

                if (best == null or value_at < best.?) {
                    best = value_at;
                }

                break;
            }

            search = at + 1;
        }
    }

    const value_at = best orelse return null;

    return .{ .value_at = value_at };
}

fn quoted_value(text: []const u8) ?[]const u8 {
    if (text.len < 2) {
        return null;
    }

    const quote = text[0];

    if (quote != '"' and quote != '\'') {
        return null;
    }

    const end = std.mem.indexOfScalarPos(u8, text, 1, quote) orelse return null;

    return text[1..end];
}

fn normalise_newlines(allocator: std.mem.Allocator, text: []const u8) ![]const u8 {
    if (std.mem.indexOf(u8, text, "\r\n") == null) {
        return text;
    }

    var out: std.Io.Writer.Allocating = .init(allocator);
    errdefer out.deinit();
    var rest = text;

    while (std.mem.indexOf(u8, rest, "\r\n")) |at| {
        try out.writer.writeAll(rest[0..at]);
        try out.writer.writeByte('\n');
        rest = rest[at + 2 ..];
    }

    try out.writer.writeAll(rest);

    return out.toOwnedSlice();
}

fn index_of_ignore_case(haystack: []const u8, from: usize, needle: []const u8) ?usize {
    std.debug.assert(needle.len > 0);

    if (haystack.len < needle.len) {
        return null;
    }

    var at = from;

    while (at + needle.len <= haystack.len) : (at += 1) {
        if (std.ascii.eqlIgnoreCase(haystack[at .. at + needle.len], needle)) {
            return at;
        }
    }

    return null;
}

fn is_word_byte(byte: u8) bool {
    return std.ascii.isAlphanumeric(byte) or byte == '_';
}

test "a valid icon yields its trimmed body" {
    const icon = try read(std.testing.allocator, "check.svg", "<svg width=\"24\" viewBox=\"0 0 24 24\" fill=\"none\">\n<path d=\"M1 1\" stroke=\"currentColor\"/>\n</svg>\n");
    try std.testing.expectEqualStrings("check", icon.name);
    try std.testing.expectEqualStrings("<path d=\"M1 1\" stroke=\"currentColor\"/>", icon.body);
}

test "every contract rule is enforced" {
    const good = "<svg viewBox=\"0 0 24 24\"><path stroke=\"currentColor\"/></svg>";
    try std.testing.expectError(error.NotKebabCase, read(std.testing.allocator, "Check.svg", good));
    try std.testing.expectError(error.NotKebabCase, read(std.testing.allocator, "a--b.svg", good));
    try std.testing.expectError(error.SocialBrand, read(std.testing.allocator, "github.svg", good));
    try std.testing.expectError(error.NoRoot, read(std.testing.allocator, "a.svg", "<svg viewBox=\"0 0 24 24\"></svg>"));
    try std.testing.expectError(error.WrongViewBox, read(std.testing.allocator, "a.svg", "<svg viewBox=\"0 0 16 16\"><path/></svg>"));
    try std.testing.expectError(error.HardcodedBlack, read(std.testing.allocator, "a.svg", "<svg viewBox=\"0 0 24 24\"><path fill='#000000'/></svg>"));
    try std.testing.expectError(error.HardcodedBlack, read(std.testing.allocator, "a.svg", "<svg viewBox=\"0 0 24 24\"><path stroke=\"Black\"/></svg>"));
    // A hyphen is a word boundary, so `data-stroke="black"` is flagged like the node script did;
    // only an attribute name that continues an identifier escapes the rule.
    try std.testing.expectError(error.HardcodedBlack, read(std.testing.allocator, "a.svg", "<svg viewBox=\"0 0 24 24\"><path data-stroke=\"black\"/></svg>"));
    _ = try read(std.testing.allocator, "a.svg", "<svg viewBox=\"0 0 24 24\"><path xstroke=\"black\" stroke=\"currentColor\"/></svg>");
}

test "CRLF bodies are normalised into owned memory" {
    const icon = try read(std.testing.allocator, "a.svg", "<svg viewBox=\"0 0 24 24\">\r\n<g/>\r\n<g/>\r\n</svg>");
    defer std.testing.allocator.free(icon.body);
    try std.testing.expectEqualStrings("<g/>\n<g/>", icon.body);
}
