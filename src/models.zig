const std = @import("std");

pub const MatchStatus = enum {
    scheduled,
    in_progress,
    final,

    pub fn label(self: MatchStatus) []const u8 {
        return switch (self) {
            .scheduled => "Scheduled",
            .in_progress => "In Progress",
            .final => "Final",
        };
    }
};

pub const Team = struct {
    id: []const u8,
    name: []const u8,
    abbreviation: []const u8,

    pub fn print(self: Team) void {
        std.debug.print("{s} ({s})", .{ self.name, self.abbreviation });
    }
};

pub const Match = struct {
    id: []const u8,
    name: []const u8,
    group: ?[]const u8,
    home: Team,
    away: Team,
    home_score: ?u8,
    away_score: ?u8,
    status: MatchStatus,

    pub fn print(self: Match) void {
        std.debug.print("{s}\n", .{self.name});
        std.debug.print("  Status: {s}\n", .{self.status.label()});

        std.debug.print(" ", .{});
        self.home.print();

        if (self.home_score) |score| {
            std.debug.print(" {d}", .{score});
        }

        std.debug.print(" vs ", .{});
        self.away.print();

        if (self.away_score) |score| {
            std.debug.print(" {d}", .{score});
        }

        std.debug.print("\n", .{});

        if (self.group) |group_name| {
            std.debug.print("  Group: {s}\n", .{group_name});
        }
    }
};
