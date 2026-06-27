const std = @import("std");

pub fn stringView(value: ?std.json.Value) ?[]const u8 {
    const actual = value orelse return null;

    return switch (actual) {
        .string => |text| text,
        else => null,
    };
}

pub fn intValue(value: ?std.json.Value) ?i16 {
    const actual = value orelse return null;

    return switch (actual) {
        .integer => |number| @intCast(number),
        .float => |number| @intFromFloat(number),
        .string => |text| std.fmt.parseInt(i16, text, 10) catch null,
        else => null,
    };
}

pub fn intValueOrZero(value: ?std.json.Value) i16 {
    return intValue(value) orelse 0;
}

pub fn dupStringField(
    allocator: std.mem.Allocator,
    value: ?std.json.Value,
    fallback: []const u8,
) ![]const u8 {
    const text = stringView(value) orelse fallback;
    return try allocator.dupe(u8, text);
}

pub fn statValue(
    stats_value: std.json.Value,
    wanted_name: []const u8,
) i16 {
    if (stats_value != .array) return 0;

    for (stats_value.array.items) |stat_value| {
        if (stat_value != .object) continue;

        const stat = stat_value.object;
        const name = stringView(stat.get("name")) orelse continue;

        if (!std.mem.eql(u8, name, wanted_name)) continue;

        if (intValue(stat.get("value"))) |value| {
            return value;
        }

        if (intValue(stat.get("displayValue"))) |value| {
            return value;
        }

        return 0;
    }

    return 0;
}
