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
    std.debug.print("Team                         Group     P  W  D  L  GF  GA  GD  Pts  FP  Status\n", .{});
    std.debug.print("----------------------------------------------------------------------------\n", .{});

    for (rows, 0..) |third, index| {
        const status = if (index < 8) "Advance" else "Eliminated";

        std.debug.print(
            "{s:<28} {s:<8} {d:>1}  {d:>1}  {d:>1}  {d:>1}  {d:>2}  {d:>2}  {d:>3}  {d:>2}  {d:>3}  {s}\n",
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
                third.row.fair_play_score,
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
    std.debug.print("Team  YC  2YRC  RC  YC+RC  Score\n", .{});
    std.debug.print("---------------------------------\n", .{});

    for (teams) |team| {
        var score_buffer: [16]u8 = undefined;
        const score_text = scoreText(&score_buffer, team.score());

        std.debug.print(
            "{s:<5} {d:>2}  {d:>4}  {d:>2}  {d:>5}  {s:>5}\n",
            .{
                team.team_abbreviation,
                @as(u16, @intCast(team.yellow_cards)),
                @as(u16, @intCast(team.second_yellow_red_cards)),
                @as(u16, @intCast(team.straight_red_cards)),
                @as(u16, @intCast(team.yellow_plus_straight_red_cards)),
                score_text,
            },
        );
    }
}

pub fn printPlayerConductDebugs(players: []const fairplay.PlayerConductDebug) void {
    if (players.len == 0) {
        std.debug.print("No player card data found.\n", .{});
        return;
    }

    std.debug.print("Fair play debug\n\n", .{});

    var current_team_id: []const u8 = "";

    for (players) |player| {
        if (!std.mem.eql(u8, current_team_id, player.team_id)) {
            current_team_id = player.team_id;

            std.debug.print(
                "{s} {s}\n",
                .{ player.team_abbreviation, player.team_name },
            );
        }

        std.debug.print(
            "  {s:<24} #{s:<8} YC={d} RC={d} plays: YC={d} RC={d}\n",
            .{
                player.player_name,
                player.player_id,
                @as(u16, @intCast(player.yellow_cards)),
                @as(u16, @intCast(player.red_cards)),
                @as(u16, @intCast(player.yellow_play_count)),
                @as(u16, @intCast(player.red_play_count)),
            },
        );
    }
}

pub fn printFairplayScanHeader(date: []const u8) void {
    std.debug.print("Fair play scan {s}\n\n", .{date});
}

pub fn printFairplayScanMatch(match: models.Match) void {
    std.debug.print(
        "{s}  {s} vs {s}\n",
        .{
            match.id,
            match.home.abbreviation,
            match.away.abbreviation,
        },
    );
}

pub fn printFairplayScanConducts(teams: []const fairplay.TeamConduct) void {
    for (teams) |team| {
        var score_buffer: [16]u8 = undefined;
        const score_text = scoreText(&score_buffer, team.score());

        std.debug.print(
            "  {s:<5} {d:>2}  {d:>4}  {d:>2}  {d:>5}  {s:>5}\n",
            .{
                team.team_abbreviation,
                countValue(team.yellow_cards),
                countValue(team.second_yellow_red_cards),
                countValue(team.straight_red_cards),
                countValue(team.yellow_plus_straight_red_cards),
                score_text,
            },
        );
    }

    std.debug.print("\n", .{});
}

fn countValue(value: i16) u16 {
    return @intCast(value);
}

fn seedName(seed: bracket.Seed) []const u8 {
    if (seed.team) |team| {
        return team.abbreviation;
    }

    return seed.label;
}

fn scoreText(buffer: *[16]u8, value: i16) []const u8 {
    if (value == 0) {
        return "0";
    }

    return std.fmt.bufPrint(buffer, "{d}", .{value}) catch "?";
}
