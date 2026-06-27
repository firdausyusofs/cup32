const std = @import("std");
const json_utils = @import("json_utils.zig");

pub const TeamConduct = struct {
    team_id: []const u8,
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
    var parsed = try std.json.parseFromSlice(std.json.Value, allocator, body, .{});
    defer parsed.deinit();

    if (parsed.value != .object) return error.InvalidSummaryJson;

    const root = parsed.value.object;

    const boxscore_value = root.get("boxscore") orelse return error.MissingBoxscore;
    if (boxscore_value != .object) return error.MissingBoxscore;

    const boxscore = boxscore_value.object;

    const teams_value = boxscore.get("teams") orelse return error.MissingTeams;
    if (teams_value != .array) return error.MissingTeams;

    var teams = try allocator.alloc(TeamConduct, teams_value.array.items.len);

    var count: usize = 0;

    for (teams_value.array.items) |team_entry_value| {
        const conduct = parseTeamConduct(allocator, team_entry_value) catch continue;

        teams[count] = conduct;
        count += 1;
    }

    return teams[0..count];
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
) !*TeamConduct {
    for (teams.items) |*team| {
        if (std.mem.eql(u8, team.team_id, team_id)) {
            return team;
        }
    }

    try teams.append(allocator, .{
        .team_id = try allocator.dupe(u8, team_id),
    });

    return &teams.items[teams.items.len - 1];
}

pub fn freeTeamConducts(
    allocator: std.mem.Allocator,
    teams: []TeamConduct,
) void {
    for (teams) |team| {
        allocator.free(team.team_id);
    }

    allocator.free(teams);
}
