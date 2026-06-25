const std = @import("std");

const scoreboard_base_url =
    "https://site.api.espn.com/apis/site/v2/sports/soccer/fifa.world/scoreboard";

pub fn buildScoreboardUrl(
    allocator: std.mem.Allocator,
    date: ?[]const u8,
) ![]const u8 {
    if (date) |value| {
        return try std.fmt.allocPrint(
            allocator,
            "{s}?dates={s}",
            .{ scoreboard_base_url, value },
        );
    }

    return allocator.dupe(u8, scoreboard_base_url);
}

pub fn fetchScoreboard(
    allocator: std.mem.Allocator,
    io: std.Io,
    date: ?[]const u8,
) ![]u8 {
    const url = try buildScoreboardUrl(allocator, date);
    defer allocator.free(url);

    const argv = [_][]const u8{
        "curl",
        "-L",
        "-s",
        url,
    };

    const result = try std.process.run(allocator, io, .{
        .argv = &argv,
    });

    defer allocator.free(result.stderr);

    if (result.term != .exited or result.term.exited != 0) {
        std.debug.print("curl failed:\n{s}\n", .{result.stderr});
        allocator.free(result.stdout);
        return error.FetchFailed;
    }

    return result.stdout;
}
