const std = @import("std");
const json_utils = @import("json_utils.zig");

pub const SlotAssignment = struct {
    option: u16,
    group: u8,
};

pub fn groupForSlot(
    allocator: std.mem.Allocator,
    io: std.Io,
    combination: []const u8,
    slot_label: []const u8,
) !?SlotAssignment {
    const body = std.Io.Dir.cwd().readFileAlloc(
        io,
        "data/third_place_annex_c.json",
        allocator,
        .limited(1024 * 1024),
    ) catch |err| {
        if (err == error.FileNotFound) {
            return error.AnnexCFileNotFound;
        }

        return err;
    };
    defer allocator.free(body);

    var parsed = try std.json.parseFromSlice(std.json.Value, allocator, body, .{});
    defer parsed.deinit();

    if (parsed.value != .array) {
        return error.InvalidAnnexCJson;
    }

    for (parsed.value.array.items) |row_value| {
        if (row_value != .object) {
            continue;
        }

        const row = row_value.object;

        const row_combination = json_utils.stringView(row.get("combination")) orelse continue;

        if (!std.mem.eql(u8, row_combination, combination)) {
            continue;
        }

        const option = json_utils.intValue(row.get("option")) orelse 0;

        const slots_value = row.get("slots") orelse return error.InvalidAnnexCJson;
        if (slots_value != .object) {
            return error.InvalidAnnexCJson;
        }

        const group_text = json_utils.stringView(slots_value.object.get(slot_label)) orelse return null;

        if (group_text.len == 0) {
            return null;
        }

        return .{
            .option = @intCast(option),
            .group = group_text[0],
        };
    }

    return null;
}
