const parsers = @as(
    []const Parser,
    @import("build/parsers.zon"),
);
const default_treesitter_abi: i32 = 15;

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{ .preferred_optimize_mode = .ReleaseSmall });
    const abi = b.option(i32, "abi", "tree-sitter ABI") orelse default_treesitter_abi;
    const curl_run = b.addSystemCommand(&.{
        "curl", "--location", "--parallel",
    });
    const untar_tool = b.addExecutable(.{
        .name = "untar_tool",
        .root_module = b.createModule(.{
            .root_source_file = b.path("scripts/untar.zig"),
            .target = target,
            .optimize = .ReleaseFast,
        }),
    });

    const config: Config = .{
        .target = target,
        .optimize = optimize,
        .abi = abi,
        .curl_run = curl_run,
        .untar_tool = untar_tool,
    };

    inline for (parsers) |parser| {
        const parser_lib = parser.build(b, &config);
        const parser_install = b.addInstallArtifact(parser_lib, .{
            .dest_dir = .{ .override = .{ .custom = "parser" } },
            .pdb_dir = .disabled,
            .implib_dir = .disabled,
        });
        b.getInstallStep().dependOn(&parser_install.step);
    }
}

const std = @import("std");
const Parser = @import("build/Parser.zig");
const Config = @import("build/Config.zig");
