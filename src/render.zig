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
            var gd_buffer: [16]u8 = undefined;
            const gd_text = signedText(&gd_buffer, row.goal_difference);

            std.debug.print(
                "{d:>2}. {s:<24} {d:>2} {d:>2} {d:>2} {d:>2} {d:>3} {d:>3} {s:>4} {d:>4}  {s}\n",
                .{
                    unsignedStat(row.rank),
                    row.team.name,
                    unsignedStat(row.played),
                    unsignedStat(row.wins),
                    unsignedStat(row.draws),
                    unsignedStat(row.losses),
                    unsignedStat(row.goals_for),
                    unsignedStat(row.goals_against),
                    gd_text,
                    unsignedStat(row.points),
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

    std.debug.print(
        "Team                         Group     P  W  D  L  GF  GA   GD  Pts   FP  Status\n",
        .{},
    );
    std.debug.print(
        "---------------------------------------------------------------------------------\n",
        .{},
    );

    for (rows, 0..) |third, index| {
        const status = if (index < 8) "Advance" else "Eliminated";

        const row = third.row;

        var gd_buffer: [16]u8 = undefined;
        var fp_buffer: [16]u8 = undefined;

        const gd_text = signedText(&gd_buffer, row.goal_difference);
        const fp_text = plainScoreText(&fp_buffer, row.fair_play_score);

        std.debug.print(
            "{s:<28} {s:<8} {d:>2} {d:>2} {d:>2} {d:>2} {d:>3} {d:>3} {s:>4} {d:>4} {s:>4}  {s}\n",
            .{
                row.team.name,
                third.group_name,
                unsignedStat(row.played),
                unsignedStat(row.wins),
                unsignedStat(row.draws),
                unsignedStat(row.losses),
                unsignedStat(row.goals_for),
                unsignedStat(row.goals_against),
                gd_text,
                unsignedStat(row.points),
                fp_text,
                status,
            },
        );
    }
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

pub fn printCardEventDebugs(events: []const fairplay.CardEventDebug) void {
    if (events.len == 0) {
        std.debug.print("No card events found.\n", .{});
        return;
    }

    std.debug.print("Card events\n\n", .{});

    for (events) |event| {
        std.debug.print(
            "{s:<5} {s:<18} #{s:<8} {s}\n",
            .{
                event.team_abbreviation,
                event.athlete_name,
                event.athlete_id,
                event.text,
            },
        );
    }
}

pub fn printBracketTree(matches: []const bracket.RoundOf32Match) void {
    std.debug.print("World Cup 2026 Bracket Tree\n", .{});
    std.debug.print("===========================\n\n", .{});

    std.debug.print("Top Left\n", .{});
    std.debug.print("--------\n", .{});
    printBracketPair(
        findRoundOf32Match(matches, "M74") orelse return,
        findRoundOf32Match(matches, "M77") orelse return,
        "M89",
    );
    printBracketPair(
        findRoundOf32Match(matches, "M73") orelse return,
        findRoundOf32Match(matches, "M75") orelse return,
        "M90",
    );
    std.debug.print("M97 = Winner M89 vs Winner M90\n\n", .{});

    std.debug.print("Top Right\n", .{});
    std.debug.print("---------\n", .{});
    printBracketPair(
        findRoundOf32Match(matches, "M76") orelse return,
        findRoundOf32Match(matches, "M78") orelse return,
        "M91",
    );
    printBracketPair(
        findRoundOf32Match(matches, "M79") orelse return,
        findRoundOf32Match(matches, "M80") orelse return,
        "M92",
    );
    std.debug.print("M99 = Winner M91 vs Winner M92\n\n", .{});

    std.debug.print("Bottom Left\n", .{});
    std.debug.print("-----------\n", .{});
    printBracketPair(
        findRoundOf32Match(matches, "M83") orelse return,
        findRoundOf32Match(matches, "M84") orelse return,
        "M93",
    );
    printBracketPair(
        findRoundOf32Match(matches, "M81") orelse return,
        findRoundOf32Match(matches, "M82") orelse return,
        "M94",
    );
    std.debug.print("M98 = Winner M93 vs Winner M94\n\n", .{});

    std.debug.print("Bottom Right\n", .{});
    std.debug.print("------------\n", .{});
    printBracketPair(
        findRoundOf32Match(matches, "M86") orelse return,
        findRoundOf32Match(matches, "M88") orelse return,
        "M95",
    );
    printBracketPair(
        findRoundOf32Match(matches, "M85") orelse return,
        findRoundOf32Match(matches, "M87") orelse return,
        "M96",
    );
    std.debug.print("M100 = Winner M95 vs Winner M96\n\n", .{});

    std.debug.print("Semifinals\n", .{});
    std.debug.print("----------\n", .{});
    std.debug.print("M101 = Winner M97 vs Winner M98\n", .{});
    std.debug.print("M102 = Winner M99 vs Winner M100\n\n", .{});

    std.debug.print("Final\n", .{});
    std.debug.print("-----\n", .{});
    std.debug.print("M104 = Winner M101 vs Winner M102\n", .{});
    std.debug.print("M103 = Third-place match\n", .{});
}

fn printBracketPair(
    first: bracket.RoundOf32Match,
    second: bracket.RoundOf32Match,
    next_match_id: []const u8,
) void {
    std.debug.print(
        "{s:<4} {s:<8} ─────┐\n",
        .{ first.match_id, seedName(first.home) },
    );
    std.debug.print(
        "     {s:<8} ─────┤ {s}\n",
        .{ seedName(first.away), next_match_id },
    );
    std.debug.print(
        "{s:<4} {s:<8} ─────┘\n",
        .{ second.match_id, seedName(second.home) },
    );
    std.debug.print(
        "     {s:<8}\n\n",
        .{seedName(second.away)},
    );
}

fn findRoundOf32Match(
    matches: []const bracket.RoundOf32Match,
    match_id: []const u8,
) ?bracket.RoundOf32Match {
    for (matches) |match| {
        if (std.mem.eql(u8, match.match_id, match_id)) {
            return match;
        }
    }

    return null;
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

fn unsignedStat(value: i16) u16 {
    if (value < 0) {
        return 0;
    }

    return @intCast(value);
}

fn signedText(buffer: *[16]u8, value: i16) []const u8 {
    if (value >= 0) {
        return std.fmt.bufPrint(buffer, "+{d}", .{value}) catch "?";
    }

    return std.fmt.bufPrint(buffer, "{d}", .{value}) catch "?";
}

fn plainScoreText(buffer: *[16]u8, value: i16) []const u8 {
    return std.fmt.bufPrint(buffer, "{d}", .{value}) catch "?";
}
