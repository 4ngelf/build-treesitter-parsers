//! Usage: {exe} ABI OUTPUT_DIR
pub fn main() !void {
    var arena: std.heap.ArenaAllocator = .init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var arg_iter: process.ArgIterator = try .initWithAllocator(allocator);
    defer arg_iter.deinit();
    std.debug.assert(arg_iter.skip());
    const abi_str = arg_iter.next() orelse return error.ExpectedAbi;
    const output_path = try fs.realpathAlloc(
        allocator,
        arg_iter.next() orelse return error.ExpectedOutputDirectory,
    );

    const h: SubprocessHelper = .{
        .allocator = allocator,
    };

    if (fs.cwd().access("src/grammar.json", .{})) |_| {
        try h.run(&.{
            "tree-sitter",      "generate",
            "--abi",            abi_str,
            "--output",         output_path,
            "src/grammar.json",
        });
    } else |err| if (err == error.FileNotFound) {
        try h.run(&.{ "npm", "install" });
        try h.run(&.{
            "tree-sitter", "generate",
            "--abi",       abi_str,
            "--output",    output_path,
            "grammar.js",
        });
    } else {
        return err;
    }
}

const SubprocessHelper = struct {
    allocator: std.mem.Allocator,

    fn run(self: *const SubprocessHelper, args: []const []const u8) !void {
        var cmd: process.Child = .init(
            args,
            self.allocator,
        );
        const term = try cmd.spawnAndWait();
        if (term.Exited != 0) return error.NonzeroTermination;
    }
};

const std = @import("std");
const process = std.process;
const fs = std.fs;
const assert = std.debug.assert;
