const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const libraw = b.addLibrary(.{
        .linkage = .static,
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
        }),
        .name = "raw",
    });

    libraw.linkLibCpp();
    libraw.linkLibC();
    if (target.result.os.tag == .windows) {
        libraw.linkSystemLibrary("ws2_32");
    }

    libraw.addIncludePath(b.path("."));

    const defines: []const []const u8 = &.{
        "-DLIBRAW_NODLL",
        "-UUSE_RAWSPEED",
        "-UUSE_DNGSDK",
    };

    const src_dirs: []const []const u8 = &.{
        "src/decoders",
        "src/decompressors",
        "src/demosaic",
        "src/integration",
        "src/metadata",
        "src/stream",
        "src/postprocessing",
        "src/preprocessing",
        "src/tables",
        "src/utils",
        "src/write",
        "src/x3f",
    };

    for (src_dirs) |dir| {
        libraw.addCSourceFiles(.{
            .files = try collectCppFiles(b, dir),
            .flags = defines,
        });
    }

    libraw.addCSourceFiles(.{
        .root = b.path(""),
        .files = &.{ "src/libraw_c_api.cpp", "src/libraw_datastream.cpp" },
        .flags = defines,
    });

    b.installArtifact(libraw);

    const example = b.addExecutable(.{
        .root_module = b.addModule("example", .{ .target = target, .optimize = optimize, .root_source_file = b.path("example/main.zig") }),
        .name = "zlr_example",
    });

    example.root_module.linkLibrary(libraw);
    example.root_module.addIncludePath(b.path("libraw/"));

    b.installArtifact(example);

    const run_cmd = b.addRunArtifact(example);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run-example", "Run example");
    run_step.dependOn(&run_cmd.step);
}

fn collectCppFiles(b: *std.Build, dir_path: []const u8) ![]const []const u8 {
    var files = try std.ArrayList([]const u8).initCapacity(b.allocator, 1);
    const abs = b.pathFromRoot(dir_path);
    var dir = std.fs.openDirAbsolute(abs, .{ .iterate = true }) catch return &.{};
    defer dir.close();

    var it = dir.iterate();
    while (it.next() catch null) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.name, ".cpp")) continue;

        if (std.mem.endsWith(u8, entry.name, "_ph.cpp")) continue;

        const full = std.fs.path.join(b.allocator, &.{ dir_path, entry.name }) catch continue;
        files.append(b.allocator, full) catch continue;
    }

    return files.toOwnedSlice(b.allocator) catch &.{};
}
