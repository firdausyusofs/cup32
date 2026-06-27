const std = @import("std");
const json_utils = @import("json_utils.zig");
const models = @import("models.zig");

pub const QualificationStatus = enum {
    advanced,
    best_third_candidate,
    eliminated,
    unknown,

    pub fn label(self: QualificationStatus) []const u8 {
        return switch (self) {
            .advanced => "Advanced",
            .best_third_candidate => "Best 8",
            .eliminated => "Eliminated",
            .unknown => "-",
        };
    }
};

pub const TableRow = struct {
    team: models.Team,
    rank: i16 = 0,
    played: i16 = 0,
    wins: i16 = 0,
    draws: i16 = 0,
    losses: i16 = 0,
    goals_for: i16 = 0,
    goals_against: i16 = 0,
    goal_difference: i16 = 0,
    points: i16 = 0,
    fair_play_score: i16 = 0,
    qualification: QualificationStatus = .unknown,
};

pub const GroupTable = struct {
    name: []const u8,
    rows: []TableRow,
};

pub const ThirdPlaceRow = struct {
    group_name: []const u8,
    row: TableRow,
};

pub fn thirdPlaceRanking(
    allocator: std.mem.Allocator,
    groups: []const GroupTable,
) ![]ThirdPlaceRow {
    var count: usize = 0;

    for (groups) |group| {
        for (group.rows) |row| {
            if (row.rank == 3) {
                count += 1;
            }
        }
    }

    var result = try allocator.alloc(ThirdPlaceRow, count);

    var index: usize = 0;
    for (groups) |group| {
        for (group.rows) |row| {
            if (row.rank == 3) {
                result[index] = ThirdPlaceRow{
                    .group_name = group.name,
                    .row = row,
                };
                index += 1;
            }
        }
    }

    std.sort.block(ThirdPlaceRow, result, {}, thirdPlaceLessThan);

    return result;
}

pub fn freeGroupTables(
    allocator: std.mem.Allocator,
    groups: []GroupTable,
) void {
    for (groups) |group| {
        allocator.free(group.name);

        for (group.rows) |row| {
            allocator.free(row.team.id);
            allocator.free(row.team.name);
            allocator.free(row.team.abbreviation);
        }

        allocator.free(group.rows);
    }

    allocator.free(groups);
}

pub fn parseStandings(
    allocator: std.mem.Allocator,
    body: []const u8,
) ![]GroupTable {
    var parsed = try std.json.parseFromSlice(std.json.Value, allocator, body, .{});
    defer parsed.deinit();

    if (parsed.value != .object) return error.InvalidStandingsJson;

    const root = parsed.value.object;
    const children_value = root.get("children") orelse return error.MissingGroups;

    if (children_value != .array) return error.MissingGroups;

    const raw_groups = children_value.array.items;
    var groups = try allocator.alloc(GroupTable, raw_groups.len);

    var group_count: usize = 0;

    for (raw_groups) |group_value| {
        const group = parseGroup(allocator, group_value) catch continue;
        groups[group_count] = group;
        group_count += 1;
    }

    return groups[0..group_count];
}

pub fn applyFairPlayScore(
    groups: []GroupTable,
    team_id: []const u8,
    score: i16,
) void {
    for (groups) |*group| {
        for (group.rows) |*row| {
            if (std.mem.eql(u8, row.team.id, team_id)) {
                row.fair_play_score += score;
                return;
            }
        }
    }
}

fn parseGroup(
    allocator: std.mem.Allocator,
    group_value: std.json.Value,
) !GroupTable {
    if (group_value != .object) return error.InvalidGroup;

    const group = group_value.object;
    const name = try json_utils.dupStringField(allocator, group.get("name"), "Unknown Group");

    const standings_value = group.get("standings") orelse return error.MissingStandings;
    if (standings_value != .object) return error.MissingStandings;

    const standings_object = standings_value.object;
    const entries_value = standings_object.get("entries") orelse return error.MissingEntries;

    if (entries_value != .array) return error.MissingEntries;

    const raw_entries = entries_value.array.items;
    var rows = try allocator.alloc(TableRow, raw_entries.len);

    var row_count: usize = 0;

    for (raw_entries) |entry_value| {
        const row = parseEntry(allocator, entry_value) catch continue;
        rows[row_count] = row;
        row_count += 1;
    }

    std.sort.block(TableRow, rows[0..row_count], {}, tableRowLessThan);

    return GroupTable{
        .name = name,
        .rows = rows[0..row_count],
    };
}

fn parseEntry(
    allocator: std.mem.Allocator,
    entry_value: std.json.Value,
) !TableRow {
    if (entry_value != .object) return error.InvalidEntry;

    const entry = entry_value.object;

    const team_value = entry.get("team") orelse return error.MissingTeam;
    if (team_value != .object) return error.MissingTeam;

    const team_object = team_value.object;

    const note_value = entry.get("note");
    const qualification = parseQualification(note_value);

    const stats_value = entry.get("stats") orelse return error.MissingStats;
    if (stats_value != .array) return error.MissingStats;

    return TableRow{
        .team = models.Team{
            .id = try json_utils.dupStringField(allocator, team_object.get("id"), "unknown-team"),
            .name = try json_utils.dupStringField(allocator, team_object.get("displayName"), "Unknown Team"),
            .abbreviation = try json_utils.dupStringField(allocator, team_object.get("abbreviation"), "UNK"),
        },
        .rank = json_utils.statValue(stats_value, "rank"),
        .played = json_utils.statValue(stats_value, "gamesPlayed"),
        .wins = json_utils.statValue(stats_value, "wins"),
        .draws = json_utils.statValue(stats_value, "ties"),
        .losses = json_utils.statValue(stats_value, "losses"),
        .goals_for = json_utils.statValue(stats_value, "pointsFor"),
        .goals_against = json_utils.statValue(stats_value, "pointsAgainst"),
        .goal_difference = json_utils.statValue(stats_value, "pointDifference"),
        .points = json_utils.statValue(stats_value, "points"),
        .qualification = qualification,
    };
}

fn parseQualification(value: ?std.json.Value) QualificationStatus {
    const note_value = value orelse return .unknown;
    if (note_value != .object) return .unknown;

    const note = note_value.object;
    const description = json_utils.stringView(note.get("description")) orelse return .unknown;

    if (std.mem.eql(u8, description, "Advanced to Round of 32")) {
        return .advanced;
    }

    if (std.mem.eql(u8, description, "Best 8 advance")) {
        return .best_third_candidate;
    }

    if (std.mem.eql(u8, description, "Eliminated")) {
        return .eliminated;
    }

    return .unknown;
}

fn tableRowLessThan(_: void, lhs: TableRow, rhs: TableRow) bool {
    if (lhs.rank != rhs.rank) {
        return lhs.rank < rhs.rank;
    }

    if (lhs.points != rhs.points) {
        return lhs.points > rhs.points;
    }

    if (lhs.goal_difference != rhs.goal_difference) {
        return lhs.goal_difference > rhs.goal_difference;
    }

    if (lhs.goals_for != rhs.goals_for) {
        return lhs.goals_for > rhs.goals_for;
    }

    return std.mem.lessThan(u8, lhs.team.name, rhs.team.name);
}

fn thirdPlaceLessThan(_: void, lhs: ThirdPlaceRow, rhs: ThirdPlaceRow) bool {
    if (lhs.row.points != rhs.row.points) {
        return lhs.row.points > rhs.row.points;
    }

    if (lhs.row.goal_difference != rhs.row.goal_difference) {
        return lhs.row.goal_difference > rhs.row.goal_difference;
    }

    if (lhs.row.goals_for != rhs.row.goals_for) {
        return lhs.row.goals_for > rhs.row.goals_for;
    }

    if (lhs.row.fair_play_score != rhs.row.fair_play_score) {
        return lhs.row.fair_play_score > rhs.row.fair_play_score;
    }

    return std.mem.lessThan(u8, lhs.row.team.name, rhs.row.team.name);
}
