//! usage: {exe} INPUT_TAR_GZ OUTPUT_DIR
pub fn main() !void {
    var arena: std.heap.ArenaAllocator = .init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var arg_iter: process.ArgIterator = try .initWithAllocator(allocator);
    defer arg_iter.deinit();
    std.debug.assert(arg_iter.skip());

    const targz_path = try fs.realpathAlloc(
        allocator,
        arg_iter.next() orelse return error.ExpectedTarGzFile,
    );
    const output_path = try fs.realpathAlloc(
        allocator,
        arg_iter.next() orelse return error.ExpectedOutputDirectory,
    );

    const targz_file = try fs.openFileAbsolute(targz_path, .{});
    defer targz_file.close();
    var output_dir = try fs.openDirAbsolute(output_path, .{ .no_follow = true });
    defer output_dir.close();

    var stream_buffer: [std.heap.page_size_min]u8 = undefined;
    var read_tar_gz = targz_file.reader(&stream_buffer);

    var decompress_buffer: [flate.max_window_len]u8 = undefined;
    var read_tar: flate.Decompress = .init(&read_tar_gz.interface, .gzip, &decompress_buffer);

    var diag: tar.Diagnostics = .{ .allocator = allocator };
    defer diag.deinit();
    try tar.pipeToFileSystem(output_dir, &read_tar.reader, .{
        .mode_mode = .ignore,
        .strip_components = 1,
        .exclude_empty_directories = true,
        .diagnostics = &diag,
    });

    var success = true;
    for (diag.errors.items) |err| switch (err) {
        .unable_to_create_sym_link => {},
        else => |unexpected_error| {
            success = false;
            std.log.err("{any}", .{unexpected_error});
        },
    };

    if (!success) return error.FailedToDecompressTarGz;
}

const std = @import("std");
const process = std.process;
const fs = std.fs;
const tar = std.tar;
const flate = std.compress.flate;
