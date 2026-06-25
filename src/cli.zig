const std = @import("std");
const espn = @import("espn.zig");

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
    } else if (std.mem.eql(u8, command, "standings")) {
        std.debug.print("World Cup group standings coming soon.\n", .{});
    } else if (std.mem.eql(u8, command, "third-place")) {
        std.debug.print("Best third-place team ranking coming soon.\n", .{});
    } else if (std.mem.eql(u8, command, "bracket")) {
        std.debug.print("FIFA World Cup Round of 32 bracket coming soon.\n", .{});
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
    var date: ?[]const u8 = null;

    var index: usize = 2;
    while (index < args.len) : (index += 1) {
        const arg = args[index];

        if (std.mem.eql(u8, arg, "--date")) {
            if (index + 1 >= args.len) {
                std.debug.print("Missing value for --date.\n", .{});
                std.debug.print("Expected format: YYYYMMDD\n", .{});
                return;
            }

            date = args[index + 1];
            index += 1;
        } else {
            std.debug.print("Unknown fetch option: {s}\n", .{arg});
            std.debug.print("Run `cup32 help` for usage.\n", .{});
            return;
        }
    }

    const body = try espn.fetchScoreboard(allocator, io, date);
    defer allocator.free(body);

    std.debug.print("{s}\n", .{body});
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
        \\  standings     Show calculated group standings
        \\  third-place   Show best third-place team ranking
        \\  bracket       Show the Round of 32 knockout bracket
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
