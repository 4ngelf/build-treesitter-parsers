const parsers = @as(
    []const Parser,
    @import("parsers.zon"),
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
            .target = b.resolveTargetQuery(.{}),
            .optimize = .ReleaseFast,
        }),
    });
    const generate_parser_tool = b.addExecutable(.{
        .name = "generate-parser",
        .root_module = b.createModule(.{
            .root_source_file = b.path("scripts/generate-parser.zig"),
            .target = b.resolveTargetQuery(.{}),
            .optimize = .ReleaseFast,
        }),
    });

    const config: Config = .{
        .target = target,
        .optimize = optimize,
        .abi = abi,
        .curl_run = curl_run,
        .untar_tool = untar_tool,
        .generate_parser_tool = generate_parser_tool,
    };

    const parser_option = b.option([]const ParserName, "parser", "parsers to compile separated by commas or `all`. [default: all]");
    const parser_set: std.EnumSet(ParserName) =
        if (parser_option) |selection| set: {
            var set: std.EnumSet(ParserName) = .initMany(selection);
            if (set.contains(.all)) set.toggleAll();
            break :set set;
        } else .initFull();

    inline for (parsers) |parser| {
        if (parser_set.contains(parser.name)) {
            const parser_lib = parser.build(b, &config);
            const parser_install = b.addInstallArtifact(parser_lib, .{
                .dest_dir = .{ .override = .{ .custom = "parser" } },
                .pdb_dir = .disabled,
                .implib_dir = .disabled,
                .dest_sub_path = @tagName(parser.name) ++ ".so",
            });
            b.getInstallStep().dependOn(&parser_install.step);
        }
    }
}

const ParserName = blk: {
    const len = parsers.len + 1;
    var names: [len]std.builtin.Type.EnumField = undefined;
    names[0] = .{ .name = "all", .value = 0 };
    for (parsers, 1..) |parser, i| {
        names[i] = .{ .name = @tagName(parser.name), .value = i };
    }
    break :blk @Type(.{ .@"enum" = .{
        .tag_type = @Type(.{ .int = .{
            .bits = @typeInfo(usize).int.bits - @clz(len),
            .signedness = .unsigned,
        } }),
        .fields = &names,
        .decls = &.{},
        .is_exhaustive = false,
    } });
};

const std = @import("std");
const Parser = @import("build/Parser.zig");
const Config = @import("build/Config.zig");
