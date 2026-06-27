const std = @import("std");
const json_utils = @import("json_utils.zig");

pub const TeamConduct = struct {
    team_id: []const u8,
    team_abbreviation: []const u8,
    team_name: []const u8,
    yellow_cards: i16 = 0,
    second_yellow_red_cards: i16 = 0,
    straight_red_cards: i16 = 0,
    yellow_plus_straight_red_cards: i16 = 0,

    pub fn score(self: TeamConduct) i16 {
        return self.yellow_cards * -1 +
            self.second_yellow_red_cards * -3 +
            self.straight_red_cards * -4 +
            self.yellow_plus_straight_red_cards * -5;
    }
};

pub const PlayerConductDebug = struct {
    team_id: []const u8,
    team_abbreviation: []const u8,
    team_name: []const u8,
    player_id: []const u8,
    player_name: []const u8,
    yellow_cards: i16 = 0,
    red_cards: i16 = 0,
    yellow_play_count: i16 = 0,
    red_play_count: i16 = 0,
};

const PlayerDiscipline = struct {
    team_id: []const u8,
    player_id: []const u8,
    yellow_cards: i16 = 0,
    second_yellow_red_cards: i16 = 0,
    straight_red_cards: i16 = 0,
};

pub fn parseSummaryConduct(
    allocator: std.mem.Allocator,
    body: []const u8,
) ![]TeamConduct {
    const players = try parseSummaryPlayerConductDebug(allocator, body);
    defer freePlayerConductDebugs(allocator, players);

    var teams: std.ArrayList(TeamConduct) = .empty;

    for (players) |player| {
        const team = try getOrCreateTeam(
            allocator,
            &teams,
            player.team_id,
            player.team_abbreviation,
            player.team_name,
        );

        applyPlayerCards(team, player);
    }

    return teams.toOwnedSlice(allocator);
}

fn applyPlayerCards(
    team: *TeamConduct,
    player: PlayerConductDebug,
) void {
    if (player.red_cards == 0) {
        team.yellow_cards += player.yellow_cards;
        return;
    }

    if (player.yellow_cards > 0 and player.red_cards > 0) {
        team.yellow_plus_straight_red_cards += player.red_cards;
        return;
    }

    team.straight_red_cards += player.red_cards;
}

pub fn parseSummaryPlayerConductDebug(
    allocator: std.mem.Allocator,
    body: []const u8,
) ![]PlayerConductDebug {
    var parsed = try std.json.parseFromSlice(std.json.Value, allocator, body, .{});
    defer parsed.deinit();

    if (parsed.value != .object) return error.InvalidSummaryJson;

    const root = parsed.value.object;

    const rosters_value = root.get("rosters") orelse return error.MissingRosters;
    if (rosters_value != .array) return error.MissingRosters;

    var players: std.ArrayList(PlayerConductDebug) = .empty;
    errdefer {
        var empty_fallback = [_]PlayerConductDebug{};
        const owned = players.toOwnedSlice(allocator) catch &empty_fallback;
        freePlayerConductDebugs(allocator, owned);
    }

    for (rosters_value.array.items) |team_roster_value| {
        try collectTeamRosterDebug(allocator, &players, team_roster_value);
    }

    return players.toOwnedSlice(allocator);
}

fn collectTeamRosterDebug(
    allocator: std.mem.Allocator,
    players: *std.ArrayList(PlayerConductDebug),
    team_roster_value: std.json.Value,
) !void {
    if (team_roster_value != .object) return;

    const team_roster = team_roster_value.object;

    const team_value = team_roster.get("team") orelse return;
    if (team_value != .object) return;

    const team = team_value.object;

    const team_id = json_utils.stringView(team.get("id")) orelse "unknown-team";
    const team_abbreviation = json_utils.stringView(team.get("abbreviation")) orelse "-";
    const team_name = json_utils.stringView(team.get("displayName")) orelse team_abbreviation;

    const rooster_value = team_roster.get("roster") orelse return;
    if (rooster_value != .array) return;

    for (rooster_value.array.items) |player_value| {
        if (player_value != .object) continue;

        const player = player_value.object;

        const athlete_value = player.get("athlete") orelse continue;
        if (athlete_value != .object) continue;

        const athlete = athlete_value.object;

        const player_id = json_utils.stringView(athlete.get("id")) orelse continue;
        const player_name = json_utils.stringView(athlete.get("displayName")) orelse continue;

        const stats_value = player.get("stats") orelse continue;
        if (stats_value != .array) continue;

        const yellow_cards = json_utils.statValue(stats_value, "yellowCards");
        const red_cards = json_utils.statValue(stats_value, "redCards");

        const yellow_play_count = countCardPlays(stats_value, "yellow");
        const red_play_count = countCardPlays(stats_value, "red");

        if (yellow_cards == 0 and
            red_cards == 0 and
            yellow_play_count == 0 and
            red_play_count == 0)
        {
            continue;
        }

        try players.append(allocator, .{
            .team_id = try allocator.dupe(u8, team_id),
            .team_abbreviation = try allocator.dupe(u8, team_abbreviation),
            .team_name = try allocator.dupe(u8, team_name),
            .player_id = try allocator.dupe(u8, player_id),
            .player_name = try allocator.dupe(u8, player_name),
            .yellow_cards = yellow_cards,
            .red_cards = red_cards,
            .yellow_play_count = yellow_play_count,
            .red_play_count = red_play_count,
        });
    }
}

fn countCardPlays(value: ?std.json.Value, card: []const u8) i16 {
    const plays_value = value orelse return 0;
    if (plays_value != .array) return 0;

    var count: i16 = 0;

    for (plays_value.array.items) |play_value| {
        if (play_value != .object) continue;

        const play = play_value.object;

        if (std.mem.eql(u8, card, "yellow")) {
            if (json_utils.boolValue(play.get("yellowCard"))) count += 1;
        } else if (std.mem.eql(u8, card, "red")) {
            if (json_utils.boolValue(play.get("redCard"))) count += 1;
        }
    }

    return count;
}

fn parseTeamConduct(
    allocator: std.mem.Allocator,
    team_entry_value: std.json.Value,
) !TeamConduct {
    if (team_entry_value != .object) return error.InvalidTeamEntry;

    const team_entry = team_entry_value.object;

    const team_value = team_entry.get("team") orelse return error.MissingTeam;
    if (team_value != .object) return error.MissingTeam;

    const team = team_value.object;
    const team_id = try json_utils.dupStringField(allocator, team.get("id"), "unknown-team");

    const statistics_value = team_entry.get("statistics") orelse return error.MissingStatistics;
    if (statistics_value != .array) return error.MissingStatistics;

    const yellow_cards = json_utils.statValue(statistics_value, "yellowCards");
    const red_cards = json_utils.statValue(statistics_value, "redCards");

    return TeamConduct{
        .team_id = team_id,
        .yellow_cards = yellow_cards,
        .straight_red_cards = red_cards,
    };
}

fn collectDisciplineFromPlay(
    allocator: std.mem.Allocator,
    players: *std.ArrayList(PlayerDiscipline),
    play_value: std.json.Value,
) !void {
    if (play_value != .object) return;

    const play = play_value.object;

    const type_value = play.get("type") orelse return;
    if (type_value != .object) return;

    const type_object = type_value.object;
    const text = json_utils.stringView(type_object.get("text")) orelse return;

    const card_type = classifyCard(text) orelse return;

    const team_value = play.get("team") orelse return;
    if (team_value != .object) return;

    const team_object = team_value.object;
    const team_id = json_utils.stringView(team_object.get("id")) orelse return;

    const athletes_value = play.get("athletesInvolved") orelse return;
    if (athletes_value != .array or athletes_value.array.items.len == 0) return;

    const athlete_value = athletes_value.array.items[0];
    if (athlete_value != .object) return;

    const athlete = athlete_value.object;
    const player_id = json_utils.stringView(athlete.get("id")) orelse return;

    var player = try getOrCreatePlayer(
        allocator,
        players,
        team_id,
        player_id,
    );

    switch (card_type) {
        .yellow => player.yellow_cards += 1,
        .second_yellow_red => player.second_yellow_red_cards += 1,
        .straight_red => player.straight_red_cards += 1,
    }
}

const CardType = enum {
    yellow,
    second_yellow_red,
    straight_red,
};

fn classifyCard(text: []const u8) ?CardType {
    if (std.mem.eql(u8, text, "Yellow Card")) {
        return .yellow;
    }

    if (std.mem.eql(u8, text, "Red Card")) {
        return .straight_red;
    }

    if (std.mem.eql(u8, text, "Second Yellow Card")) {
        return .second_yellow_red;
    }

    if (std.mem.eql(u8, text, "Second Yellow")) {
        return .second_yellow_red;
    }

    return null;
}

fn getOrCreatePlayer(
    allocator: std.mem.Allocator,
    players: *std.ArrayList(PlayerDiscipline),
    team_id: []const u8,
    player_id: []const u8,
) !*PlayerDiscipline {
    for (players.items) |*player| {
        if (std.mem.eql(u8, player.team_id, team_id) and
            std.mem.eql(u8, player.player_id, player_id))
        {
            return player;
        }
    }

    try players.append(allocator, .{
        .team_id = try allocator.dupe(u8, team_id),
        .player_id = try allocator.dupe(u8, player_id),
    });

    return &players.items[players.items.len - 1];
}

fn summarizePlayers(
    allocator: std.mem.Allocator,
    players: []const PlayerDiscipline,
) ![]TeamConduct {
    var teams: std.ArrayList(TeamConduct) = .empty;

    for (players) |player| {
        var team = try getOrCreateTeam(
            allocator,
            &teams,
            player.team_id,
        );

        if (player.yellow_cards > 0 and player.straight_red_cards > 0) {
            team.yellow_plus_straight_red_cards += 1;
        } else if (player.second_yellow_red_cards > 0) {
            team.second_yellow_red_cards += 1;
        } else if (player.straight_red_cards > 0) {
            team.straight_red_cards += 1;
        } else {
            team.yellow_cards += player.yellow_cards;
        }
    }

    return teams.toOwnedSlice(allocator);
}

fn getOrCreateTeam(
    allocator: std.mem.Allocator,
    teams: *std.ArrayList(TeamConduct),
    team_id: []const u8,
    team_abbreviation: []const u8,
    team_name: []const u8,
) !*TeamConduct {
    for (teams.items) |*team| {
        if (std.mem.eql(u8, team.team_id, team_id)) {
            return team;
        }
    }

    try teams.append(allocator, .{
        .team_id = try allocator.dupe(u8, team_id),
        .team_abbreviation = try allocator.dupe(u8, team_abbreviation),
        .team_name = try allocator.dupe(u8, team_name),
    });

    return &teams.items[teams.items.len - 1];
}

pub fn freeTeamConducts(
    allocator: std.mem.Allocator,
    teams: []TeamConduct,
) void {
    for (teams) |team| {
        allocator.free(team.team_id);
        allocator.free(team.team_abbreviation);
        allocator.free(team.team_name);
    }

    allocator.free(teams);
}

pub fn freePlayerConductDebugs(
    allocator: std.mem.Allocator,
    players: []PlayerConductDebug,
) void {
    for (players) |player| {
        allocator.free(player.team_id);
        allocator.free(player.team_abbreviation);
        allocator.free(player.team_name);
        allocator.free(player.player_id);
        allocator.free(player.player_name);
    }

    allocator.free(players);
}
