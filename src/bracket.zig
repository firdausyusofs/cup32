const std = @import("std");
const models = @import("models.zig");
const standings = @import("standings.zig");

pub const SeedKind = enum {
    group_winner,
    group_runner_up,
    third_place,

    pub fn label(self: SeedKind) []const u8 {
        return switch (self) {
            .group_winner => "Winner",
            .group_runner_up => "Runner-up",
            .third_place => "Third",
        };
    }
};

pub const QualifiedTeam = struct {
    group_name: []const u8,
    team: models.Team,
    group_rank: i16,
    seed_kind: SeedKind,
    points: i16,
    goal_difference: i16,
    goals_for: i16,
};

pub fn qualifiedTeams(
    allocator: std.mem.Allocator,
    groups: []const standings.GroupTable,
) ![]QualifiedTeam {
    var count: usize = 0;

    for (groups) |group| {
        for (group.rows) |row| {
            if (row.rank == 1 or row.rank == 2) {
                count += 1;
            }
        }
    }

    const third_place_rows = try standings.thirdPlaceRanking(allocator, groups);
    defer allocator.free(third_place_rows);

    const third_place_count = @min(third_place_rows.len, 8);
    count += third_place_count;

    var result = try allocator.alloc(QualifiedTeam, count);

    var index: usize = 0;

    for (groups) |group| {
        for (group.rows) |row| {
            if (row.rank == 1) {
                result[index] = fromTableRow(group.name, row, .group_winner);
                index += 1;
            } else if (row.rank == 2) {
                result[index] = fromTableRow(group.name, row, .group_runner_up);
                index += 1;
            }
        }
    }

    var third_index: usize = 0;
    while (third_index < third_place_count) : (third_index += 1) {
        const third = third_place_rows[third_index];
        result[index] = fromTableRow(third.group_name, third.row, .third_place);
        index += 1;
    }

    std.sort.block(QualifiedTeam, result, {}, qualifiedTeamsLessThan);

    return result;
}

fn fromTableRow(
    group_name: []const u8,
    row: standings.TableRow,
    seed_kind: SeedKind,
) QualifiedTeam {
    return QualifiedTeam{
        .group_name = group_name,
        .team = row.team,
        .group_rank = row.rank,
        .seed_kind = seed_kind,
        .points = row.points,
        .goal_difference = row.goal_difference,
        .goals_for = row.goals_for,
    };
}

fn qualifiedTeamsLessThan(_: void, lhs: QualifiedTeam, rhs: QualifiedTeam) bool {
    const lhs_group = groupNumber(lhs.group_name);
    const rhs_group = groupNumber(rhs.group_name);

    if (lhs_group != rhs_group) {
        return lhs_group < rhs_group;
    }

    if (lhs.group_rank != rhs.group_rank) {
        return lhs.group_rank < rhs.group_rank;
    }

    return std.mem.lessThan(u8, lhs.team.name, rhs.team.name);
}

fn groupNumber(group_name: []const u8) i16 {
    const marker = "Group ";
    const index = std.mem.indexOf(u8, group_name, marker) orelse return 999;
    const number_start = index + marker.len;

    if (number_start >= group_name.len) return 999;

    const group_char = group_name[number_start];

    if (group_char >= 'A' and group_char <= 'Z') {
        return @as(i16, group_char - 'A') + 1;
    }

    return 999;
}
