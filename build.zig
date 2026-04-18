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
        .files = &.{"src/libraw_c_api.cpp"},
        .flags = defines,
    });

    const build_step = b.step("test-build", "Builds libraw");
    build_step.dependOn(&libraw.step);

    b.installArtifact(libraw);
}

fn collectCppFiles(b: *std.Build, dir_path: []const u8) ![]const []const u8 {
    var files = try std.ArrayList([]const u8).initCapacity(b.allocator, 1);
    var dir = std.fs.cwd().openDir(dir_path, .{ .iterate = true }) catch return &.{};
    defer dir.close();

    var it = dir.iterate();
    while (it.next() catch null) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.name, ".cpp")) continue;
        const full = std.fs.path.join(b.allocator, &.{ dir_path, entry.name }) catch continue;
        files.append(b.allocator, full) catch continue;
    }

    return files.toOwnedSlice(b.allocator) catch &.{};
}
