const std = @import("std");
const json_utils = @import("json_utils.zig");

pub const SlotAssignment = struct {
    option: u16,
    group: u8,
};

const Assignment = struct {
    option: u16,
    combination: []const u8,
    slots: [slot_labels.len]u8,
};

pub const Table = struct {
    assignments: []Assignment,

    pub fn deinit(
        self: *Table,
        allocator: std.mem.Allocator,
    ) void {
        for (self.assignments) |assignment| {
            allocator.free(assignment.combination);
        }

        allocator.free(self.assignments);
    }

    pub fn groupForSlot(
        self: *const Table,
        combination: []const u8,
        slot_label: []const u8,
    ) ?SlotAssignment {
        const index = slotIndex(slot_label) orelse return null;

        for (self.assignments) |assignment| {
            if (!std.mem.eql(u8, assignment.combination, combination)) {
                continue;
            }

            return .{
                .option = assignment.option,
                .group = assignment.slots[index],
            };
        }

        return null;
    }
};

const slot_labels = [_][]const u8{
    "3CEFHI", // vs 1A
    "3EFGIJ", // vs 1B
    "3BEFGJ", // vs 1D
    "3ABCDF", // vs 1E
    "3AEHIJ", // vs 1G
    "3CDFGH", // vs 1I
    "3DEIJL", // vs 1K
    "3EHIJK", // vs 1L
};

pub fn load(
    allocator: std.mem.Allocator,
    io: std.Io,
) !Table {
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

    const rows = parsed.value.array.items;
    var assignments = try allocator.alloc(Assignment, rows.len);
    var count: usize = 0;

    errdefer {
        for (assignments[0..count]) |assignment| {
            allocator.free(assignment.combination);
        }

        allocator.free(assignments);
    }

    for (rows) |row_value| {
        if (row_value != .object) {
            continue;
        }

        const row = row_value.object;

        const combination = json_utils.stringView(row.get("combination")) orelse {
            return error.InvalidAnnexCJson;
        };

        const option = json_utils.intValue(row.get("option")) orelse {
            return error.InvalidAnnexCJson;
        };

        const slots_value = row.get("slots") orelse {
            return error.InvalidAnnexCJson;
        };

        if (slots_value != .object) {
            return error.InvalidAnnexCJson;
        }

        var slots: [slot_labels.len]u8 = undefined;

        for (slot_labels, 0..) |slot_label, index| {
            const group_text = json_utils.stringView(
                slots_value.object.get(slot_label),
            ) orelse {
                return error.InvalidAnnexCJson;
            };

            if (group_text.len != 1) {
                return error.InvalidAnnexCJson;
            }

            slots[index] = group_text[0];
        }

        assignments[count] = .{
            .option = @intCast(option),
            .combination = try allocator.dupe(u8, combination),
            .slots = slots,
        };
        count += 1;
    }

    return .{
        .assignments = assignments,
    };
}

fn slotIndex(slot_label: []const u8) ?usize {
    for (slot_labels, 0..) |label, index| {
        if (std.mem.eql(u8, label, slot_label)) {
            return index;
        }
    }

    return null;
}
