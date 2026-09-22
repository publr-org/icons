//! Regenerates every adapter from `icons/*.svg`: the TypeScript module, the Zig
//! module, the manifest, the gallery page and the Figma plugin. Reading the
//! icons validates them; a bad file stops the run with its name and the rule
//! it broke. `zig build gen` runs this; `zig build test` proves the committed
//! artifacts are what this would generate.
const std = @import("std");
const svg = @import("build/svg.zig");
const emit = @import("build/emit.zig");
const gallery = @import("build/gallery.zig");
const figma = @import("build/figma.zig");

const icons_dir = "icons";
const file_bytes_max = 1 << 20;

pub const Outputs = struct {
    typescript: []const u8,
    zig_adapter: []const u8,
    manifest: []const u8,
    gallery: []const u8,
    figma: []const u8,
};

pub const Artifact = struct { path: []const u8, field: []const u8 };

pub const artifacts = [_]Artifact{
    .{ .path = "src/index.ts", .field = "typescript" },
    .{ .path = "publr_icons.zig", .field = "zig_adapter" },
    .{ .path = "manifest.json", .field = "manifest" },
    .{ .path = "index.html", .field = "gallery" },
    .{ .path = "figma-plugin/code.js", .field = "figma" },
};

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const arena = init.arena.allocator();
    // A bad icon has already named itself and the rule it broke; no trace needed.
    const icons = load_icons(arena, io) catch std.process.exit(1);
    const outputs = try generate(arena, icons);

    inline for (artifacts) |artifact| {
        try write_file(io, artifact.path, @field(outputs, artifact.field));
    }

    var buffer: [128]u8 = undefined;
    var stdout: std.Io.File.Writer = .init(.stdout(), io, &buffer);
    try stdout.interface.print("Generated {d} UI icons: TypeScript, Zig, manifest, gallery, Figma plugin.\n", .{icons.len});
    try stdout.interface.flush();
}

/// Every `icons/*.svg`, validated, in byte order of the filename.
pub fn load_icons(allocator: std.mem.Allocator, io: std.Io) ![]const svg.Icon {
    var dir = try std.Io.Dir.cwd().openDir(io, icons_dir, .{ .iterate = true });
    defer dir.close(io);

    var files: std.ArrayList([]const u8) = .empty;
    var walker = try dir.walk(allocator);
    defer walker.deinit();

    while (try walker.next(io)) |entry| {
        if (entry.kind != .file or !std.mem.endsWith(u8, entry.basename, ".svg")) {
            continue;
        }

        try files.append(allocator, try allocator.dupe(u8, entry.basename));
    }

    if (files.items.len == 0) {
        return error.NoIcons;
    }

    std.mem.sort([]const u8, files.items, {}, less_than);

    var icons: std.ArrayList(svg.Icon) = .empty;

    for (files.items) |file| {
        const source = try dir.readFileAlloc(io, file, allocator, .limited(file_bytes_max));
        const icon = svg.read(allocator, file, source) catch |problem| {
            std.debug.print("{s}/{s}: {s}\n", .{ icons_dir, file, describe(problem) });

            return problem;
        };
        try icons.append(allocator, icon);
    }

    std.debug.assert(icons.items.len == files.items.len);

    return icons.toOwnedSlice(allocator);
}

pub fn generate(allocator: std.mem.Allocator, icons: []const svg.Icon) !Outputs {
    std.debug.assert(icons.len > 0);

    return .{
        .typescript = try emit.typescript(allocator, icons),
        .zig_adapter = try emit.zig_adapter(allocator, icons),
        .manifest = try emit.manifest(allocator, icons),
        .gallery = try gallery.page(allocator, icons),
        .figma = try figma.plugin(allocator, icons),
    };
}

fn describe(problem: anyerror) []const u8 {
    return switch (problem) {
        error.NotKebabCase => "filenames must be lowercase kebab-case",
        error.SocialBrand => "social/brand icons are not allowed",
        error.NoRoot => "expected one non-empty <svg> root",
        error.WrongViewBox => "expected viewBox=\"0 0 24 24\"",
        error.HardcodedBlack => "use currentColor instead of a hardcoded black color",
        else => @errorName(problem),
    };
}

fn less_than(_: void, left: []const u8, right: []const u8) bool {
    return std.mem.lessThan(u8, left, right);
}

fn write_file(io: std.Io, path: []const u8, bytes: []const u8) !void {
    std.debug.assert(bytes.len > 0);

    const file = try std.Io.Dir.cwd().createFile(io, path, .{});
    defer file.close(io);
    var buffer: [64 * 1024]u8 = undefined;
    var writer = file.writer(io, &buffer);
    try writer.interface.writeAll(bytes);
    try writer.interface.flush();
}

test {
    _ = svg;
    _ = emit;
    _ = gallery;
    _ = figma;
    _ = @import("build/json.zig");
    _ = @import("build/template.zig");
}

// The checks below read the repository, so `zig build test` runs them from its root.

fn read_committed(allocator: std.mem.Allocator, io: std.Io, path: []const u8) ![]const u8 {
    return std.Io.Dir.cwd().readFileAlloc(io, path, allocator, .limited(file_bytes_max));
}

test "the committed artifacts are exactly what the icons generate" {
    var arena_state = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const io = std.testing.io;

    // A bad icon has already named itself and the rule it broke; no trace needed.
    const icons = load_icons(arena, io) catch std.process.exit(1);
    const outputs = try generate(arena, icons);

    inline for (artifacts) |artifact| {
        const committed = try read_committed(arena, io, artifact.path);
        std.testing.expectEqualStrings(committed, @field(outputs, artifact.field)) catch |failure| {
            std.debug.print("{s} is stale: run `zig build gen`\n", .{artifact.path});

            return failure;
        };
    }
}

const container_controls = [_][]const u8{
    "container-width", "bleed-none",     "bleed-left",   "bleed-right",     "bleed-both",
    "justify-start",   "justify-center", "justify-end",  "justify-between", "justify-around",
    "justify-evenly",  "align-start",    "align-center", "align-end",       "align-stretch",
    "align-baseline",  "wrap-none",      "wrap",         "wrap-reverse",    "sidebar-right",
    "viewport-fit",
};
const spacing_controls = [_][]const u8{
    "border-radius-corner",       "border-radius-top-left",    "border-radius-top-right",
    "border-radius-bottom-right", "border-radius-bottom-left", "spacing-sides-top",
    "spacing-sides-right",        "spacing-sides-bottom",      "spacing-sides-left",
    "spacing-sync-top-bottom",    "spacing-sync-left-right",
};
const editor_controls = [_][]const u8{
    "palette",          "viewport-compare",   "layout",           "responsive",
    "loader",           "grip-vertical",      "text-align-left",  "text-align-center",
    "text-align-right", "token-library",      "fonts-icons",      "container-sizes",
    "semantic-colors",  "element-typography", "primitive-blocks", "pattern-library",
};
const social_leaks = [_][]const u8{ "facebook", "github", "instagram", "linkedin", "tiktok", "x", "youtube" };

fn has_icon(icons: []const svg.Icon, name: []const u8) bool {
    for (icons) |icon| {
        if (std.mem.eql(u8, icon.name, name)) {
            return true;
        }
    }

    return false;
}

test "the package contains UI icons but no social brands" {
    var arena_state = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena_state.deinit();
    const icons = try load_icons(arena_state.allocator(), std.testing.io);

    try std.testing.expect(has_icon(icons, "plus"));
    try std.testing.expect(has_icon(icons, "settings"));

    for (container_controls ++ spacing_controls ++ editor_controls) |control| {
        std.testing.expect(has_icon(icons, control)) catch |failure| {
            std.debug.print("{s} is missing from the control sets\n", .{control});

            return failure;
        };
    }

    for (social_leaks) |social| {
        try std.testing.expect(!has_icon(icons, social));
    }
}

test "selection artwork exposes a semantic guide and consistent rounded weight" {
    var arena_state = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const io = std.testing.io;

    for ([_][]const u8{ "icons/spacing-sides-top.svg", "icons/border-radius-top-left.svg" }) |path| {
        const artwork = try read_committed(arena, io, path);
        try std.testing.expect(std.mem.indexOf(u8, artwork, "var(--publr-icon-guide, #666666)") != null);
        try std.testing.expect(std.mem.indexOf(u8, artwork, "stroke-width=\"2.25\"") != null);
        try std.testing.expect(std.mem.indexOf(u8, artwork, "stroke-linecap=\"round\"") != null);
        try std.testing.expect(std.mem.indexOf(u8, artwork, "stroke=\"currentColor\"") != null);
    }
}

test "the gallery, the plugin and both adapters cover every icon" {
    var arena_state = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const io = std.testing.io;

    const icons = try load_icons(arena, io);
    const outputs = try generate(arena, icons);
    const figma_manifest = try read_committed(arena, io, "figma-plugin/manifest.json");

    try std.testing.expect(std.mem.indexOf(u8, figma_manifest, "\"editorType\": [\"figma\"]") != null);
    try std.testing.expect(std.mem.indexOf(u8, figma_manifest, "\"allowedDomains\": [\"none\"]") != null);
    try std.testing.expectEqual(icons.len, std.mem.count(u8, outputs.gallery, "class=\"icon-card\""));
    try std.testing.expectEqual(icons.len, std.mem.count(u8, outputs.figma, "\"name\":"));

    for (icons) |icon| {
        const needles = .{
            .{ outputs.gallery, try std.fmt.allocPrint(arena, "data-name=\"{s}\"", .{icon.name}) },
            .{ outputs.figma, try std.fmt.allocPrint(arena, "\"name\":\"{s}\"", .{icon.name}) },
            .{ outputs.typescript, try std.fmt.allocPrint(arena, "\"{s}\":", .{icon.name}) },
        };

        inline for (needles) |needle| {
            try std.testing.expect(std.mem.indexOf(u8, needle[0], needle[1]) != null);
        }

        const identifier = try arena.dupe(u8, icon.name);
        std.mem.replaceScalar(u8, identifier, '-', '_');
        const zig_needle = try std.fmt.allocPrint(arena, "pub const {s}:", .{identifier});
        try std.testing.expect(std.mem.indexOf(u8, outputs.zig_adapter, zig_needle) != null);
    }
}
