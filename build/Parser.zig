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
    needs_scanner: bool = false,
    c_sources: ?[]const []const u8 = null,
};

pub fn build(self: *const Parser, b: *Build, config: *const Config) *Build.Step.Compile {
    const tsname = "tree-sitter-" ++ @tagName(self.name);
    const targz_url = getTarGzFromRepo(b, self.install.url, self.install.revision);

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

    if (self.install.needs_scanner)
        parser.root_module.addCSourceFile(.{
            .file = repository.path(b, "src/scanner.c"),
        });

    if (self.install.c_sources) |c_sources|
        parser.root_module.addCSourceFiles(.{
            .root = repository,
            .files = c_sources,
        });

    return parser;
}

fn getTarGzFromRepo(b: *Build, url: []const u8, revision: []const u8) []const u8 {
    const uri = std.Uri.parse(url) catch
        std.debug.panic("fix url '{s}' in parsers.zon", .{url});
    const host = uri.getHostAlloc(b.allocator) catch @panic("OOM");

    if (std.mem.eql(u8, host, "github.com"))
        return getTarGzFromGitHubOrCodeberg(b, url, revision)
    else if (std.mem.eql(u8, host, "gitlab.com"))
        return getTarGzFromGitLab(
            b,
            url,
            revision,
            std.fs.path.basename(uri.path.percent_encoded),
        )
    else if (std.mem.eql(u8, host, "codeberg.org"))
        return getTarGzFromGitHubOrCodeberg(b, url, revision)
    else if (std.mem.eql(u8, host, "sr.ht"))
        @panic("not implemented for sourcehut"); // TODO:

    unreachable;
}

fn getTarGzFromGitHubOrCodeberg(b: *Build, url: []const u8, revision: []const u8) []const u8 {
    return std.fmt.allocPrint(b.allocator, "{s}/archive/{s}.tar.gz", .{
        url,
        revision,
    }) catch @panic("OOM");
}

fn getTarGzFromGitLab(b: *Build, url: []const u8, revision: []const u8, name: []const u8) []const u8 {
    return std.fmt.allocPrint(b.allocator, "{s}/-/archive/{s}/{s}-{s}.tar.gz", .{
        url,
        revision,
        name,
        revision,
    }) catch @panic("OOM");
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
const Build = std.Build;
const Config = @import("Config.zig");
