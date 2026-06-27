const std = @import("std");

pub const Assignment = struct {
    option: u16,
    groups: []const u8,
    vs_1a: u8,
    vs_1b: u8,
    vs_1d: u8,
    vs_1e: u8,
    vs_1g: u8,
    vs_1i: u8,
    vs_1k: u8,
    vs_1l: u8,
};

const assignments = [_]Assignment{.{
    .option = 363,
    .groups = "ABDEFGIL",
    .vs_1a = 'E',
    .vs_1b = 'G',
    .vs_1d = 'B',
    .vs_1e = 'D',
    .vs_1g = 'A',
    .vs_1i = 'F',
    .vs_1k = 'L',
    .vs_1l = 'I',
}};

pub fn groupForSlot(
    combination: []const u8,
    slot_label: []const u8,
) ?u8 {
    const assignment = assignmentForCombination(combination) orelse return null;

    if (std.mem.eql(u8, slot_label, "3CEFHI")) return assignment.vs_1a;
    if (std.mem.eql(u8, slot_label, "3EFGIJ")) return assignment.vs_1b;
    if (std.mem.eql(u8, slot_label, "3BEFGJ")) return assignment.vs_1d;
    if (std.mem.eql(u8, slot_label, "3ABCDF")) return assignment.vs_1e;
    if (std.mem.eql(u8, slot_label, "3AEHIJ")) return assignment.vs_1g;
    if (std.mem.eql(u8, slot_label, "3CDFGH")) return assignment.vs_1i;
    if (std.mem.eql(u8, slot_label, "3DEIJL")) return assignment.vs_1k;
    if (std.mem.eql(u8, slot_label, "3EHIJK")) return assignment.vs_1l;

    return null;
}

pub fn assignmentForCombination(combination: []const u8) ?Assignment {
    for (assignments) |assignment| {
        if (std.mem.eql(u8, assignment.groups, combination)) {
            return assignment;
        }
    }

    return null;
}
