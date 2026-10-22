const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // The icons as SVG markup, for Zig programs that draw them (native apps).
    _ = b.addModule("publr_icons", .{
        .root_source_file = b.path("publr_icons.zig"),
    });

    const generator = b.addExecutable(.{
        .name = "icons-build",
        .root_module = b.createModule(.{
            .root_source_file = b.path("scripts/build.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    b.installArtifact(generator);

    const gen = b.addRunArtifact(generator);
    gen.setCwd(b.path("."));
    gen.has_side_effects = true;
    b.step("gen", "Regenerate the adapters, manifest, gallery and Figma plugin from icons/").dependOn(&gen.step);

    const publr_http = b.dependency("publr_http", .{
        .target = target,
        .release = optimize != .Debug,
    });
    const server = b.addExecutable(.{
        .name = "icons-serve",
        .root_module = b.createModule(.{
            .root_source_file = b.path("scripts/serve.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{.{
                .name = "publr_http",
                .module = publr_http.module("publr_http"),
            }},
        }),
    });
    b.installArtifact(server);

    const serve = b.addRunArtifact(server);
    serve.setCwd(b.path("."));
    if (b.args) |args| serve.addArgs(args);
    b.step("serve", "Serve the gallery at http://127.0.0.1:8092 (flags after --, e.g. --port 9000)").dependOn(&serve.step);

    const unit = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("scripts/build.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_unit = b.addRunArtifact(unit);
    run_unit.setCwd(b.path("."));
    const test_step = b.step("test", "Generator tests, plus proof that the committed artifacts are current");
    test_step.dependOn(&run_unit.step);

    // Publr's tidy, holding this repo to the workspace's options rule (STYLE.md) alone so far.
    const tidy = b.addExecutable(.{
        .name = "tidy",
        .root_module = b.createModule(.{
            .root_source_file = b.path("../publr/scripts/tidy.zig"),
            .target = b.graph.host,
            .optimize = .Debug,
        }),
    });
    const run_tidy = b.addRunArtifact(tidy);
    run_tidy.addArgs(&.{ "--only=options", "build.zig", "publr_icons.zig", "scripts" });
    run_tidy.setCwd(b.path("."));
    run_tidy.has_side_effects = true;
    b.step("tidy", "Check the workspace's options rule").dependOn(&run_tidy.step);
    test_step.dependOn(&run_tidy.step);
}
