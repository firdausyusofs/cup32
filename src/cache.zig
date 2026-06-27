const std = @import("std");

const cache_root = ".cup32-cache";

pub fn read(
    allocator: std.mem.Allocator,
    io: std.Io,
    namespace: []const u8,
    key: []const u8,
) !?[]u8 {
    const path = try cachePath(allocator, namespace, key);
    defer allocator.free(path);

    const file = std.Io.Dir.cwd().openFile(io, path, .{}) catch |err| {
        if (err == error.FileNotFound) {
            return null;
        }

        return err;
    };
    defer file.close(io);

    const size = try file.length(io);
    const contents = try allocator.alloc(u8, size);

    const bytes_read = try file.readPositionalAll(io, contents, 0);
    return contents[0..bytes_read];
}

pub fn write(
    allocator: std.mem.Allocator,
    io: std.Io,
    namespace: []const u8,
    key: []const u8,
    body: []const u8,
) !void {
    const directory_path = try namespacePath(allocator, namespace);
    defer allocator.free(directory_path);

    try std.Io.Dir.cwd().createDirPath(io, directory_path);

    const path = try cachePath(allocator, namespace, key);
    defer allocator.free(path);

    const file = try std.Io.Dir.cwd().createFile(io, path, .{
        .truncate = true,
    });
    defer file.close(io);

    try file.writeStreamingAll(io, body);
}

pub fn exists(
    allocator: std.mem.Allocator,
    io: std.Io,
    namespace: []const u8,
    key: []const u8,
) !bool {
    const path = try cachePath(allocator, namespace, key);
    defer allocator.free(path);

    const file = std.Io.Dir.cwd().openFile(io, path, .{}) catch |err| {
        if (err == error.FileNotFound) {
            return false;
        }

        return err;
    };

    file.close(io);
    return true;
}

fn namespacePath(
    allocator: std.mem.Allocator,
    namespace: []const u8,
) ![]u8 {
    return std.fmt.allocPrint(
        allocator,
        "{s}/{s}",
        .{ cache_root, namespace },
    );
}

fn cachePath(
    allocator: std.mem.Allocator,
    namespace: []const u8,
    key: []const u8,
) ![]u8 {
    return std.fmt.allocPrint(
        allocator,
        "{s}/{s}/{s}",
        .{ cache_root, namespace, key },
    );
}
