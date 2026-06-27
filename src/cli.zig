const std = @import("std");
const bracket = @import("bracket.zig");
const cache = @import("cache.zig");
const fairplay = @import("fairplay.zig");
const espn = @import("espn.zig");
const models = @import("models.zig");
const render = @import("render.zig");
const standings = @import("standings.zig");

const group_stage_dates = [_][]const u8{
    "20260611",
    "20260612",
    "20260613",
    "20260614",
    "20260615",
    "20260616",
    "20260617",
    "20260618",
    "20260619",
    "20260620",
    "20260621",
    "20260622",
    "20260623",
    "20260624",
    "20260625",
    "20260626",
};

pub fn run(
    allocator: std.mem.Allocator,
    io: std.Io,
    args: []const [:0]const u8,
) !void {
    if (args.len < 2) {
        printHelp();
        return;
    }

    const command = args[1];

    if (std.mem.eql(u8, command, "fetch")) {
        try handleFetch(allocator, io, args);
    } else if (std.mem.eql(u8, command, "matches")) {
        try handleMatches(allocator, io, args);
    } else if (std.mem.eql(u8, command, "standings")) {
        try handleStandings(allocator, io);
    } else if (std.mem.eql(u8, command, "third-place")) {
        try handleThirdPlace(allocator, io);
    } else if (std.mem.eql(u8, command, "third-place-fairplay")) {
        try handleThirdPlaceFairplay(allocator, io);
    } else if (std.mem.eql(u8, command, "bracket")) {
        try handleBracket(allocator, io);
    } else if (std.mem.eql(u8, command, "summary")) {
        try handleSummary(allocator, io, args);
    } else if (std.mem.eql(u8, command, "fairplay")) {
        try handleFairplay(allocator, io, args);
    } else if (std.mem.eql(u8, command, "fairplay-debug")) {
        try handleFairplayDebug(allocator, io, args);
    } else if (std.mem.eql(u8, command, "fairplay-scan")) {
        try handleFairplayScan(allocator, io, args);
    } else if (std.mem.eql(u8, command, "demo-match")) {
        try handleDemoMatch();
    } else if (std.mem.eql(u8, command, "cache-test")) {
        try handleCacheTest(allocator, io);
    } else if (std.mem.eql(u8, command, "help")) {
        printHelp();
    } else {
        std.debug.print("Unknown command: {s}\n\n", .{command});
        printHelp();
    }
}

fn handleFetch(
    allocator: std.mem.Allocator,
    io: std.Io,
    args: []const [:0]const u8,
) !void {
    const date = try parseDateOption(args);

    const body = try espn.fetchScoreboard(allocator, io, date);
    defer allocator.free(body);

    std.debug.print("{s}\n", .{body});
}

fn handleMatches(
    allocator: std.mem.Allocator,
    io: std.Io,
    args: []const [:0]const u8,
) !void {
    const date = try parseDateOption(args);

    const body = try espn.fetchScoreboard(allocator, io, date);
    defer allocator.free(body);

    const matches = try espn.parseScoreboard(allocator, body);

    render.printMatches(matches);
}

fn handleStandings(
    allocator: std.mem.Allocator,
    io: std.Io,
) !void {
    const body = try espn.fetchStandings(allocator, io);
    defer allocator.free(body);

    const groups = try standings.parseStandings(allocator, body);
    defer standings.freeGroupTables(allocator, groups);

    render.printGroupTables(groups);
}

fn handleThirdPlace(
    allocator: std.mem.Allocator,
    io: std.Io,
) !void {
    const body = try espn.fetchStandings(allocator, io);
    defer allocator.free(body);

    const groups = try standings.parseStandings(allocator, body);
    defer standings.freeGroupTables(allocator, groups);

    const rows = try standings.thirdPlaceRanking(allocator, groups);
    defer allocator.free(rows);

    render.printThirdPlaceRanking(rows);
}

fn handleThirdPlaceFairplay(
    allocator: std.mem.Allocator,
    io: std.Io,
) !void {
    const body = try espn.fetchStandings(allocator, io);
    defer allocator.free(body);

    const groups = try standings.parseStandings(allocator, body);
    defer standings.freeGroupTables(allocator, groups);

    try applyGroupStageFairPlayScores(allocator, io, groups);

    const third_places = try standings.thirdPlaceRanking(allocator, groups);
    defer allocator.free(third_places);

    render.printThirdPlaceRanking(third_places);
}

fn applyGroupStageFairPlayScores(
    allocator: std.mem.Allocator,
    io: std.Io,
    groups: []standings.GroupTable,
) !void {
    for (group_stage_dates) |date| {
        const scoreboard_body = try espn.fetchScoreboard(allocator, io, date);
        defer allocator.free(scoreboard_body);

        const matches = try espn.parseScoreboard(allocator, scoreboard_body);
        defer espn.freeMatches(allocator, matches);

        for (matches) |match| {
            if (match.status != .final) {
                continue;
            }

            const summary_body = try espn.fetchSummary(
                allocator,
                io,
                match.id,
                true,
            );
            defer allocator.free(summary_body);

            const conducts = try fairplay.parseSummaryConduct(
                allocator,
                summary_body,
            );
            defer fairplay.freeTeamConducts(allocator, conducts);

            for (conducts) |conduct| {
                standings.applyFairPlayScore(
                    groups,
                    conduct.team_id,
                    conduct.score(),
                );
            }
        }
    }
}

fn handleBracket(
    allocator: std.mem.Allocator,
    io: std.Io,
) !void {
    const body = try espn.fetchStandings(allocator, io);
    defer allocator.free(body);

    const groups = try standings.parseStandings(allocator, body);
    defer standings.freeGroupTables(allocator, groups);

    const matches = try bracket.roundOf32(allocator, groups);
    defer bracket.freeRoundOf32(allocator, matches);

    render.printRoundOf32(matches);
}

fn handleSummary(
    allocator: std.mem.Allocator,
    io: std.Io,
    args: []const [:0]const u8,
) !void {
    if (args.len < 3) {
        std.debug.print("Missing event id.\n", .{});
        std.debug.print("Usage: cup32 summary <event-id>\n", .{});
        return;
    }

    const event_id = args[2];

    const body = try espn.fetchSummary(
        allocator,
        io,
        event_id,
        true,
    );
    defer allocator.free(body);

    std.debug.print("{s}\n", .{body});
}

fn handleFairplay(
    allocator: std.mem.Allocator,
    io: std.Io,
    args: []const [:0]const u8,
) !void {
    if (args.len < 3) {
        std.debug.print("Missing event id.\n", .{});
        std.debug.print("Usage: cup32 fairplay <event_id>\n", .{});
        return;
    }

    const event_id = args[2];

    const body = try espn.fetchSummary(
        allocator,
        io,
        event_id,
        true,
    );
    defer allocator.free(body);

    const teams = try fairplay.parseSummaryConduct(allocator, body);
    defer fairplay.freeTeamConducts(allocator, teams);

    render.printTeamConducts(teams);
}

fn handleFairplayDebug(
    allocator: std.mem.Allocator,
    io: std.Io,
    args: []const [:0]const u8,
) !void {
    if (args.len < 3) {
        std.debug.print("Missing event id.\n", .{});
        std.debug.print("Usage: cup32 fairplay-debug <event_id>\n", .{});
        return;
    }

    const event_id = args[2];

    const body = try espn.fetchSummary(
        allocator,
        io,
        event_id,
        true,
    );
    defer allocator.free(body);

    const players = try fairplay.parseSummaryPlayerConductDebug(allocator, body);
    defer fairplay.freePlayerConductDebugs(allocator, players);

    render.printPlayerConductDebugs(players);
}

fn handleFairplayScan(
    allocator: std.mem.Allocator,
    io: std.Io,
    args: []const [:0]const u8,
) !void {
    if (args.len < 3) {
        std.debug.print("Missing date.\n", .{});
        std.debug.print("Usage: cup32 fairplay-scan <YYYYMMDD>\n", .{});
        return;
    }

    const date = args[2];

    const body = try espn.fetchScoreboard(allocator, io, date);
    defer allocator.free(body);

    const matches = try espn.parseScoreboard(allocator, body);
    defer espn.freeMatches(allocator, matches);

    render.printFairplayScanHeader(date);

    for (matches) |match| {
        if (match.status != .final) {
            continue;
        }

        const summary = try espn.fetchSummary(
            allocator,
            io,
            match.id,
            true,
        );
        defer allocator.free(summary);

        const conducts = try fairplay.parseSummaryConduct(
            allocator,
            summary,
        );
        defer fairplay.freeTeamConducts(allocator, conducts);

        render.printFairplayScanMatch(match);
        render.printFairplayScanConducts(conducts);
    }
}

fn parseDateOption(args: []const [:0]const u8) !?[]const u8 {
    var date: ?[]const u8 = null;

    var index: usize = 2;
    while (index < args.len) : (index += 1) {
        const arg = args[index];

        if (std.mem.eql(u8, arg, "--date")) {
            if (index + 1 >= args.len) {
                std.debug.print("Missing value for --date.\n", .{});
                std.debug.print("Expected format: YYYYMMDD\n", .{});
                return error.MissingDateValue;
            }

            date = args[index + 1];
            index += 1;
        } else {
            std.debug.print("Unknown fetch option: {s}\n", .{arg});
            std.debug.print("Run `cup32 help` for usage.\n", .{});
            return error.UnknownOption;
        }
    }

    return date;
}

fn handleDemoMatch() !void {
    const home = models.Team{
        .id = "team-mexico",
        .name = "Mexico",
        .abbreviation = "MEX",
    };

    const away = models.Team{
        .id = "team-south-africa",
        .name = "South Africa",
        .abbreviation = "RSA",
    };

    const match = models.Match{
        .id = "66456904",
        .name = "Mexico vs South Africa",
        .group = "Group A",
        .home = home,
        .away = away,
        .home_score = 2,
        .away_score = 0,
        .status = .final,
    };

    render.printMatch(match);
}

fn handleCacheTest(
    allocator: std.mem.Allocator,
    io: std.Io,
) !void {
    const namespace = "summary";
    const key = "test.json";
    const body =
        \\{"ok":true,"source":"cup32-cache-test"}
    ;

    try cache.write(allocator, io, namespace, key, body);

    const cached = try cache.read(allocator, io, namespace, key);
    defer if (cached) |value| allocator.free(value);

    if (cached) |value| {
        std.debug.print("{s}\n", .{value});
    } else {
        std.debug.print("Ceche miss.\n", .{});
    }
}

fn printHelp() void {
    std.debug.print(
        \\cup32
        \\A Zig CLI for tracking and rendering the FIFA World Cup Round of 32 bracket.
        \\
        \\Usage:
        \\  cup32 <command>
        \\
        \\Commands:
        \\  fetch         Fetch World Cup scoreboard data from ESPN
        \\  matches       Fetch and print parsed World Cup matches
        \\  standings     Show calculated group standings
        \\  third-place   Show best third-place team ranking
        \\  bracket       Show the Round of 32 knockout bracket
        \\  summary       Fetch and cache ESPN match summary by event id
        \\  help          Show this help message
        \\
        \\Fetch options:
        \\  --date YYYYMMDD   Use ESPN scoreboard date filter
        \\
        \\Examples:
        \\  cup32 fetch
        \\  cup32 fetch --date 20260628
        \\
    , .{});
}
