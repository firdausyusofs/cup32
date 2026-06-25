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
};
