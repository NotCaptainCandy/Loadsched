const std = @import("std");

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});

    const targets: []const std.Target.Query = &.{
        .{ .cpu_arch = .x86_64, .os_tag = .windows, .abi = .gnu },
        .{ .cpu_arch = .aarch64, .os_tag = .windows, .abi = .gnu },
        .{ .cpu_arch = .x86_64, .os_tag = .linux, .abi = .musl },
        .{ .cpu_arch = .aarch64, .os_tag = .linux, .abi = .musl },
        .{ .cpu_arch = .x86_64, .os_tag = .macos, .abi = null },
        .{ .cpu_arch = .aarch64, .os_tag = .macos, .abi = null }, // Apple Silicon
    };

    for (targets) |query| {
        const resolved = b.resolveTargetQuery(query);

        const exe = b.addExecutable(.{
            .name = "plant_sizer",
            .root_module = b.createModule(.{
                .root_source_file = b.path("src/main.zig"),
                .target = resolved,
                .optimize = optimize,
            }),
        });

        // Output each binary into zig-out/<arch>-<os>/
        const target_output = b.addInstallArtifact(exe, .{
            .dest_dir = .{
                .override = .{
                    .custom = b.fmt("{s}-{s}", .{
                        @tagName(query.cpu_arch.?),
                        @tagName(query.os_tag.?),
                    }),
                },
            },
        });
        b.getInstallStep().dependOn(&target_output.step);
    }
}
