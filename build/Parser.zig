//! Information about a parser
const Parser = @This();

name: @Type(.enum_literal),
maintainers: []const @Type(.enum_literal),
tier: i32,
install: InstallInfo,

const InstallInfo = struct {
    url: []const u8,
    revision: []const u8,
    subpath: ?[]const u8 = null,
    c_sources: ?[]const []const u8 = null,
};

pub fn build(self: *const Parser, b: *Build, config: *const Config) *Build.Step.Compile {
    const tsname = "tree-sitter-" ++ @tagName(self.name);
    const targz_url = getArchiveFromRepo(b, &self.install);

    config.curl_run.addArg(targz_url);
    const targz = config.curl_run.addPrefixedOutputFileArg("-o", tsname ++ ".tar.gz");

    const untar_run = b.addRunArtifact(config.untar_tool);
    untar_run.addFileArg(targz);
    const repository = untar_run.addOutputDirectoryArg(tsname ++ "-tmp");

    const parser_dir = addTreeSitterGenerate(b, .{
        .cwd = if (self.install.subpath) |subpath|
            repository.path(b, subpath)
        else
            repository,
        .abi = config.abi,
        .directory_output = tsname ++ "-src",
    });

    const parser = b.addLibrary(.{
        .name = @tagName(self.name),
        .linkage = .dynamic,
        .root_module = b.createModule(.{
            .target = config.target,
            .optimize = config.optimize,
            .link_libc = true,
        }),
    });
    parser.root_module.addIncludePath(parser_dir);
    parser.root_module.addCSourceFile(.{
        .file = parser_dir.path(b, "parser.c"),
    });

    if (self.install.c_sources) |c_sources|
        parser.root_module.addCSourceFiles(.{
            .root = repository,
            .files = c_sources,
        });

    return parser;
}

fn getArchiveFromRepo(b: *Build, install: *const InstallInfo) []const u8 {
    // TODO: gitlab
    // TODO: codeberg
    // TODO: sourcehut
    const targz_url = std.fmt.allocPrint(b.allocator, "{s}/archive/{s}.tar.gz", .{
        install.url,
        install.revision,
    }) catch @panic("OOM");
    return targz_url;
}

const TreeSitterGenerateOptions = struct {
    cwd: Build.LazyPath,
    abi: i32,
    directory_output: []const u8,
};

fn addTreeSitterGenerate(b: *Build, opts: TreeSitterGenerateOptions) Build.LazyPath {
    const run = b.addSystemCommand(&.{
        "tree-sitter", "generate",
        "--abi",       intToStr(b, opts.abi),
    });
    run.setCwd(opts.cwd);
    return run.addPrefixedOutputDirectoryArg("-o", opts.directory_output);
}

fn intToStr(b: *Build, int: anytype) []const u8 {
    return std.fmt.allocPrint(b.allocator, "{d}", .{int}) catch @panic("OOM");
}

const std = @import("std");
const tar = std.tar;
const flate = std.compress.flate;
const Build = std.Build;
const Config = @import("Config.zig");
