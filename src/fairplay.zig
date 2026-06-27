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

pub const CardEventDebug = struct {
    team_id: []const u8,
    team_abbreviation: []const u8,
    team_name: []const u8,
    athlete_id: []const u8,
    athlete_name: []const u8,
    text: []const u8,
};

const TeamInfo = struct {
    id: []const u8,
    abbreviation: []const u8,
    name: []const u8,
};

pub fn parseScoreboardCardEventDebug(
    allocator: std.mem.Allocator,
    body: []const u8,
    wanted_event_id: []const u8,
) ![]CardEventDebug {
    var parsed = try std.json.parseFromSlice(std.json.Value, allocator, body, .{});
    defer parsed.deinit();

    if (parsed.value != .object) return error.InvalidSummaryJson;

    const root = parsed.value.object;

    const events_value = root.get("events") orelse return error.MissingEvents;
    if (events_value != .array) return error.MissingEvents;

    var events: std.ArrayList(CardEventDebug) = .empty;
    errdefer {
        for (events.items) |event| {
            allocator.free(event.team_id);
            allocator.free(event.team_abbreviation);
            allocator.free(event.team_name);
            allocator.free(event.athlete_id);
            allocator.free(event.athlete_name);
            allocator.free(event.text);
        }

        events.deinit(allocator);
    }

    for (events_value.array.items) |event_value| {
        if (event_value != .object) continue;

        const event = event_value.object;
        const event_id = json_utils.stringView(event.get("id")) orelse continue;

        if (!std.mem.eql(u8, event_id, wanted_event_id)) {
            continue;
        }

        try collectCardEventsFromEvent(allocator, &events, event_value);
    }

    return events.toOwnedSlice(allocator);
}

pub fn applyCardEventsToConducts(
    allocator: std.mem.Allocator,
    events: []const CardEventDebug,
) ![]TeamConduct {
    var teams: std.ArrayList(TeamConduct) = .empty;

    for (events) |event| {
        const team = try getOrCreateTeam(
            allocator,
            &teams,
            event.team_id,
            event.team_abbreviation,
            event.team_name,
        );

        applyCardEvent(team, event.text);
    }

    return teams.toOwnedSlice(allocator);
}

fn applyCardEvent(
    team: *TeamConduct,
    text: []const u8,
) void {
    if (std.mem.eql(u8, text, "Yellow Card")) {
        team.yellow_cards += 1;
        return;
    }

    if (std.mem.eql(u8, text, "Red Card")) {
        team.straight_red_cards += 1;
        return;
    }

    if (std.mem.indexOf(u8, text, "Second Yellow") != null) {
        team.second_yellow_red_cards += 1;
        return;
    }
}

fn collectCardEventsFromEvent(
    allocator: std.mem.Allocator,
    events: *std.ArrayList(CardEventDebug),
    event_value: std.json.Value,
) !void {
    if (event_value != .object) return;

    const event = event_value.object;

    const competitions_value = event.get("competitions") orelse return;
    if (competitions_value != .array) return;

    for (competitions_value.array.items) |competition_value| {
        if (competition_value != .object) continue;

        const competition = competition_value.object;

        const details_value = competition.get("details") orelse continue;
        if (details_value != .array) continue;

        for (details_value.array.items) |detail_value| {
            try collectOneCardEvent(
                allocator,
                events,
                competition,
                detail_value,
            );
        }
    }
}

fn collectOneCardEvent(
    allocator: std.mem.Allocator,
    events: *std.ArrayList(CardEventDebug),
    competition: std.json.ObjectMap,
    detail_value: std.json.Value,
) !void {
    if (detail_value != .object) return;

    const detail = detail_value.object;

    const type_value = detail.get("type") orelse return;
    if (type_value != .object) return;

    const type_obj = type_value.object;
    const text = json_utils.stringView(type_obj.get("text")) orelse return;

    if (!isCardText(text)) return;

    const team_id = detailTeamId(detail) orelse return;
    const team_info = resolveTeamInfo(competition, team_id);

    const team_abbreviation = if (team_info) |info| info.abbreviation else "-";
    const team_name = if (team_info) |info| info.name else team_abbreviation;

    var athlete_id: []const u8 = "-";
    var athlete_name: []const u8 = "-";

    if (detail.get("athletesInvolved")) |athletes_value| {
        if (athletes_value == .array and athletes_value.array.items.len > 0) {
            const athlete_value = athletes_value.array.items[0];

            if (athlete_value == .object) {
                const athlete = athlete_value.object;

                athlete_id = json_utils.stringView(athlete.get("id")) orelse "-";
                athlete_name = json_utils.stringView(athlete.get("displayName")) orelse "-";
            }
        }
    }

    try events.append(allocator, .{
        .team_id = try allocator.dupe(u8, team_id),
        .team_abbreviation = try allocator.dupe(u8, team_abbreviation),
        .team_name = try allocator.dupe(u8, team_name),
        .athlete_id = try allocator.dupe(u8, athlete_id),
        .athlete_name = try allocator.dupe(u8, athlete_name),
        .text = try allocator.dupe(u8, text),
    });
}

fn detailTeamId(detail: std.json.ObjectMap) ?[]const u8 {
    if (detail.get("team")) |team_value| {
        if (team_value == .object) {
            const team = team_value.object;

            if (json_utils.stringView(team.get("id"))) |id| {
                return id;
            }
        }
    }

    if (detail.get("athletesInvolved")) |athletes_value| {
        if (athletes_value == .array and athletes_value.array.items.len > 0) {
            const athlete_value = athletes_value.array.items[0];

            if (athlete_value == .object) {
                const athlete = athlete_value.object;

                if (athlete.get("team")) |team_value| {
                    if (team_value != .object) return null;

                    const team = team_value.object;

                    if (json_utils.stringView(team.get("id"))) |id| {
                        return id;
                    }
                }
            }
        }
    }

    return null;
}

fn resolveTeamInfo(
    competition: std.json.ObjectMap,
    wanted_team_id: []const u8,
) ?TeamInfo {
    const competitors_value = competition.get("competitors") orelse return null;
    if (competitors_value != .array) return null;

    for (competitors_value.array.items) |competitor_value| {
        if (competitor_value != .object) continue;

        const competitor = competitor_value.object;

        const team_value = competitor.get("team") orelse continue;
        if (team_value != .object) continue;

        const team = team_value.object;

        const id = json_utils.stringView(team.get("id")) orelse continue;

        if (!std.mem.eql(u8, id, wanted_team_id)) {
            continue;
        }

        const abbreviation = json_utils.stringView(team.get("abbreviation")) orelse "-";
        const name = json_utils.stringView(team.get("displayName")) orelse abbreviation;

        return .{
            .id = id,
            .abbreviation = abbreviation,
            .name = name,
        };
    }

    return null;
}

fn isCardText(text: []const u8) bool {
    return std.mem.indexOf(u8, text, "Card") != null;
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

pub fn freeCardEventDebugs(
    allocator: std.mem.Allocator,
    events: []CardEventDebug,
) void {
    for (events) |event| {
        allocator.free(event.team_id);
        allocator.free(event.team_abbreviation);
        allocator.free(event.team_name);
        allocator.free(event.athlete_id);
        allocator.free(event.athlete_name);
        allocator.free(event.text);
    }

    allocator.free(events);
}
