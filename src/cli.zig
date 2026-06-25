const std = @import("std");

pub fn run(args: []const [:0]const u8) !void {
    const stdout = std.debug;

    if (args.len < 2) {
        printHelp();
        return;
    }

    const command = args[1];

    if (std.mem.eql(u8, command, "fetch")) {
        stdout.print("Fetching World Cup scoreboard data...\n", .{});
        stdout.print("ESPN integration coming in the next step.\n", .{});
    } else if (std.mem.eql(u8, command, "standings")) {
        stdout.print("World Cup group standings coming soon.\n", .{});
    } else if (std.mem.eql(u8, command, "third-place")) {
        stdout.print("Best third-place team ranking coming soon.\n", .{});
    } else if (std.mem.eql(u8, command, "bracket")) {
        stdout.print("FIFA World Cup Round of 32 bracket coming soon.\n", .{});
    } else if (std.mem.eql(u8, command, "help")) {
        printHelp();
    } else {
        stdout.print("Unknown command: {s}\n\n", .{command});
        printHelp();
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
        \\  standings     Show calculated group standings
        \\  third-place   Show best third-place team ranking
        \\  bracket       Show the Round of 32 knockout bracket
        \\  help          Show this help message
        \\
    , .{});
}
