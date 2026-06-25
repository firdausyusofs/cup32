const std = @import("std");
const models = @import("models.zig");

const scoreboard_base_url =
    "https://site.api.espn.com/apis/site/v2/sports/soccer/fifa.world/scoreboard";

pub fn buildScoreboardUrl(
    allocator: std.mem.Allocator,
    date: ?[]const u8,
) ![]const u8 {
    if (date) |value| {
        return try std.fmt.allocPrint(
            allocator,
            "{s}?dates={s}",
            .{ scoreboard_base_url, value },
        );
    }

    return allocator.dupe(u8, scoreboard_base_url);
}

pub fn fetchScoreboard(
    allocator: std.mem.Allocator,
    io: std.Io,
    date: ?[]const u8,
) ![]u8 {
    const url = try buildScoreboardUrl(allocator, date);
    defer allocator.free(url);

    const argv = [_][]const u8{
        "curl",
        "-L",
        "-s",
        url,
    };

    const result = try std.process.run(allocator, io, .{
        .argv = &argv,
    });

    defer allocator.free(result.stderr);

    if (result.term != .exited or result.term.exited != 0) {
        std.debug.print("curl failed:\n{s}\n", .{result.stderr});
        allocator.free(result.stdout);
        return error.FetchFailed;
    }

    return result.stdout;
}

pub fn parseScoreboard(
    allocator: std.mem.Allocator,
    body: []const u8,
) ![]models.Match {
    var parsed = try std.json.parseFromSlice(std.json.Value, allocator, body, .{});
    defer parsed.deinit();

    if (parsed.value != .object) {
        return error.InvalidScoreboardJson;
    }

    const root = parsed.value.object;
    const events_value = root.get("events") orelse {
        return allocator.alloc(models.Match, 0);
    };

    if (events_value != .array) {
        return error.InvalidScoreboardJson;
    }

    const raw_events = events_value.array.items;
    var matches = try allocator.alloc(models.Match, raw_events.len);

    var count: usize = 0;

    for (raw_events) |event_value| {
        const parsed_match = parseEvent(allocator, event_value) catch continue;
        matches[count] = parsed_match;
        count += 1;
    }

    return matches[0..count];
}

fn parseEvent(
    allocator: std.mem.Allocator,
    event_value: std.json.Value,
) !models.Match {
    if (event_value != .object) {
        return error.InvalidEvent;
    }

    const event = event_value.object;

    const id = try dupStringField(allocator, event.get("id"), "unknown-event");
    const name = try dupStringField(allocator, event.get("name"), "unknown match");

    const competitions_value = event.get("competitions") orelse return error.MissingCompetitions;
    if (competitions_value != .array or competitions_value.array.items.len == 0) {
        return error.MissingCompetitions;
    }

    const competition_value = competitions_value.array.items[0];
    if (competition_value != .object) {
        return error.InvalidCompetition;
    }

    const competition = competition_value.object;

    const competitors_value = competition.get("competitors") orelse return error.MissingCompetitors;
    if (competitors_value != .array) {
        return error.MissingCompetitors;
    }

    var home_value: ?std.json.Value = null;
    var away_value: ?std.json.Value = null;

    for (competitors_value.array.items) |competitor_value| {
        if (competitor_value != .object) continue;

        const competitor = competitor_value.object;
        const home_away = stringView(competitor.get("homeAway")) orelse continue;

        if (std.mem.eql(u8, home_away, "home")) {
            home_value = competitor_value;
        } else if (std.mem.eql(u8, home_away, "away")) {
            away_value = competitor_value;
        }
    }

    const home = try parseCompetitor(allocator, home_value orelse return error.MissingHomeTeam);
    const away = try parseCompetitor(allocator, away_value orelse return error.MissingAwayTeam);

    const home_score = parseCompetitorScore(home_value.?);
    const away_score = parseCompetitorScore(away_value.?);

    const group = try parseGroup(allocator, competition.get("altGameNote"));

    return models.Match{
        .id = id,
        .name = name,
        .group = group,
        .home = home.team,
        .away = away.team,
        .home_score = home_score,
        .away_score = away_score,
        .status = parseStatus(competition_value),
    };
}

const ParsedCompetitor = struct {
    team: models.Team,
};

fn parseCompetitor(
    allocator: std.mem.Allocator,
    competitor_value: std.json.Value,
) !ParsedCompetitor {
    if (competitor_value != .object) {
        return error.InvalidCompetitor;
    }

    const competitor = competitor_value.object;

    const team_value = competitor.get("team") orelse return error.MissingTeam;
    if (team_value != .object) {
        return error.MissingTeam;
    }

    const team = team_value.object;

    return ParsedCompetitor{
        .team = models.Team{
            .id = try dupStringField(allocator, team.get("id"), "unknown-team"),
            .name = try dupStringField(allocator, team.get("name"), "Unknown Team"),
            .abbreviation = try dupStringField(allocator, team.get("abbreviation"), "UNK"),
        },
    };
}

fn parseCompetitorScore(competitor_value: std.json.Value) ?u8 {
    if (competitor_value != .object) return null;

    const competitor = competitor_value.object;
    const score_text = stringView(competitor.get("score")) orelse return null;

    return std.fmt.parseInt(u8, score_text, 10) catch null;
}

fn parseStatus(competition_value: std.json.Value) models.MatchStatus {
    if (competition_value != .object) return .scheduled;

    const competition = competition_value.object;
    const status_value = competition.get("status") orelse return .scheduled;

    if (status_value != .object) return .scheduled;

    const status = status_value.object;
    const type_value = status.get("type") orelse return .scheduled;

    if (type_value != .object) return .scheduled;

    const status_type = type_value.object;

    if (stringView(status_type.get("state"))) |state| {
        if (std.mem.eql(u8, state, "pre")) return .scheduled;
        if (std.mem.eql(u8, state, "in")) return .in_progress;
        if (std.mem.eql(u8, state, "post")) return .final;
    }

    return .scheduled;
}

fn parseGroup(
    allocator: std.mem.Allocator,
    value: ?std.json.Value,
) !?[]const u8 {
    const note = stringView(value) orelse return null;

    const marker = "Group ";
    const index = std.mem.indexOf(u8, note, marker) orelse return null;

    const group = try allocator.dupe(u8, note[index..]);
    return group;
}

fn dupStringField(
    allocator: std.mem.Allocator,
    value: ?std.json.Value,
    fallback: []const u8,
) ![]const u8 {
    const text = stringView(value) orelse fallback;
    return allocator.dupe(u8, text);
}

fn stringView(value: ?std.json.Value) ?[]const u8 {
    const actual = value orelse return null;

    return switch (actual) {
        .string => |text| text,
        else => null,
    };
}

const standings_url =
    "https://site.api.espn.com/apis/v2/sports/soccer/fifa.world/standings";

pub fn buildStandingsUrl(
    allocator: std.mem.Allocator,
) ![]const u8 {
    return allocator.dupe(u8, standings_url);
}

pub fn fetchStandings(
    allocator: std.mem.Allocator,
    io: std.Io,
) ![]u8 {
    const url = try buildStandingsUrl(allocator);
    defer allocator.free(url);

    const argv = [_][]const u8{
        "curl",
        "-L",
        "-s",
        url,
    };

    const result = try std.process.run(allocator, io, .{
        .argv = &argv,
    });

    defer allocator.free(result.stderr);

    if (result.term != .exited or result.term.exited != 0) {
        std.debug.print("curl failed:\n{s}\n", .{result.stderr});
        allocator.free(result.stdout);
        return error.FetchFailed;
    }

    return result.stdout;
}
