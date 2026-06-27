const std = @import("std");
const bracket = @import("bracket.zig");
const fairplay = @import("fairplay.zig");
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

pub fn printThirdPlaceRanking(rows: []const standings.ThirdPlaceRow) void {
    if (rows.len == 0) {
        std.debug.print("No third-place teams found.\n", .{});
        return;
    }

    std.debug.print("Best third-place teams\n", .{});
    std.debug.print("Team                         Group     P  W  D  L  GF  GA  GD  Pts  Status\n", .{});
    std.debug.print("----------------------------------------------------------------------------\n", .{});

    for (rows, 0..) |third, index| {
        const status = if (index < 8) "Advance" else "Eliminated";

        std.debug.print(
            "{s:<28} {s:<8} {d:>1}  {d:>1}  {d:>1}  {d:>1}  {d:>2}  {d:>2}  {d:>3}  {d:>3}  {s}\n",
            .{
                third.row.team.name,
                third.group_name,
                third.row.played,
                third.row.wins,
                third.row.draws,
                third.row.losses,
                third.row.goals_for,
                third.row.goals_against,
                third.row.goal_difference,
                third.row.points,
                status,
            },
        );
    }
}

pub fn printQualifiedTeams(teams: []const bracket.QualifiedTeam) void {
    if (teams.len == 0) {
        std.debug.print("No qualified teams found.\n", .{});
        return;
    }

    std.debug.print("Qualified teams for Round of 32\n", .{});
    std.debug.print("Group     Rank  Team                         Seed       Pts  GD  GF\n", .{});
    std.debug.print("-------------------------------------------------------------------\n", .{});

    for (teams) |qualified| {
        std.debug.print(
            "{s:<8} {d:>4}  {s:<28} {s:<9} {d:>3}  {d:>3} {d:>3}\n",
            .{
                qualified.group_name,
                qualified.group_rank,
                qualified.team.name,
                qualified.seed_kind.label(),
                qualified.points,
                qualified.goal_difference,
                qualified.goals_for,
            },
        );
    }

    std.debug.print("\nTotal qualified: {d}\n", .{teams.len});
}

pub fn printRoundOf32(matches: []const bracket.RoundOf32Match) void {
    if (matches.len == 0) {
        std.debug.print("No Round of 32 matches found.\n", .{});
        return;
    }

    std.debug.print("Round of 32\n", .{});
    std.debug.print("Match  Date        Time   Home                         Away\n", .{});
    std.debug.print("-----------------------------------------------------------------------\n", .{});

    for (matches) |match| {
        std.debug.print(
            "{s:<5}  {s:<10}  {s:<5}  {s:<28} {s}\n",
            .{
                match.match_id,
                match.date,
                match.time,
                seedName(match.home),
                seedName(match.away),
            },
        );
    }
}

pub fn printTeamConducts(teams: []const fairplay.TeamConduct) void {
    if (teams.len == 0) {
        std.debug.print("No card events found.\n", .{});
        return;
    }

    std.debug.print("Team conduct scores\n", .{});
    std.debug.print("Team ID  YC  2YRC  RC  YC+RC  Score\n", .{});
    std.debug.print("------------------------------------\n", .{});

    for (teams) |team| {
        std.debug.print(
            "{s:<7} {d:>2}  {d:>4}  {d:>2}  {d:>5}  {d:>5}\n",
            .{
                team.team_id,
                @as(u16, @intCast(team.yellow_cards)),
                @as(u16, @intCast(team.second_yellow_red_cards)),
                @as(u16, @intCast(team.straight_red_cards)),
                @as(u16, @intCast(team.yellow_plus_straight_red_cards)),
                team.score(),
            },
        );
    }
}

fn seedName(seed: bracket.Seed) []const u8 {
    if (seed.team) |team| {
        return team.abbreviation;
    }

    return seed.label;
}
