const c = @cImport({
    @cInclude("libraw.h");
});
const std = @import("std");

pub fn main() !void {
    const processor = c.libraw_init(0) orelse return error.FailedToInitRaw;
    defer c.libraw_close(processor);
    std.debug.print("LibRaw version: {s}\n", .{c.libraw_version()});
}
