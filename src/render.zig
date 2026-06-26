const std = @import("std");
const models = @import("models.zig");
const standings = @import("standings.zig");

pub fn printMatch(match: models.Match) void {
    std.debug.print("{s}\n", .{match.name});
    std.debug.print("  Status: {s}\n", .{match.status.label()});

    std.debug.print(" ", .{});
    printTeam(match.home);

    if (match.home_score) |score| {
        std.debug.print(" {d}", .{score});
    }

    std.debug.print(" vs ", .{});
    printTeam(match.away);

    if (match.away_score) |score| {
        std.debug.print(" {d}", .{score});
    }

    std.debug.print("\n", .{});

    if (match.group) |group_name| {
        std.debug.print("  Group: {s}\n", .{group_name});
    }
}

pub fn printMatches(matches: []const models.Match) void {
    if (matches.len == 0) {
        std.debug.print("No matches found.\n", .{});
        return;
    }

    for (matches) |match| {
        printMatch(match);
        std.debug.print("\n", .{});
    }
}

fn printTeam(team: models.Team) void {
    std.debug.print("{s} ({s})", .{ team.name, team.abbreviation });
}

pub fn printGroupTables(groups: []const standings.GroupTable) void {
    if (groups.len == 0) {
        std.debug.print("No standings found.\n", .{});
        return;
    }

    for (groups) |group| {
        std.debug.print("{s}\n", .{group.name});
        std.debug.print("Team                         P  W  D  L  GF  GA  GD  Pts  Status\n", .{});
        std.debug.print("-------------------------------------------------------------------\n", .{});

        for (group.rows) |row| {
            std.debug.print(
                "{s:<28} {d:>1}  {d:>1}  {d:>1}  {d:>1}  {d:>2}  {d:>2}  {d:>3}  {d:>3}  {s}\n",
                .{
                    row.team.name,
                    row.played,
                    row.wins,
                    row.draws,
                    row.losses,
                    row.goals_for,
                    row.goals_against,
                    row.goal_difference,
                    row.points,
                    row.qualification.label(),
                },
            );
        }

        std.debug.print("\n", .{});
    }
}
