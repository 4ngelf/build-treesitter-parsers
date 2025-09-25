target: std.Build.ResolvedTarget,
optimize: std.builtin.OptimizeMode,
abi: i32,
curl_run: *std.Build.Step.Run,
untar_tool: *std.Build.Step.Compile,

const std = @import("std");
