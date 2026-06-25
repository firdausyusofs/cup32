const std = @import("std");

const scoreboard_base_url =
    "https://site.api.espn.com/apis/site/v2/sports/soccer/fifa.world/scoreboard";

pub fn printScoreboardUrl(date: ?[]const u8) void {
    if (date) |value| {
        std.debug.print("{s}?dates={s}\n", .{ scoreboard_base_url, value });
    } else {
        std.debug.print("{s}\n", .{scoreboard_base_url});
    }
}
