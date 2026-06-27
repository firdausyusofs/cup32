const std = @import("std");
const models = @import("models.zig");
const standings = @import("standings.zig");
const third_place_annex_c = @import("third_place_annex_c.zig");

pub const Seed = struct {
    label: []const u8,
    team: ?models.Team,
};

pub const RoundOf32Match = struct {
    match_id: []const u8,
    date: []const u8,
    time: []const u8,
    home: Seed,
    away: Seed,
};

const ThirdPlaceResolver = struct {
    rows: []const standings.ThirdPlaceRow,
    used: []bool,
    annex_c: *const third_place_annex_c.Table,

    fn claim(
        self: *ThirdPlaceResolver,
        label: []const u8,
    ) !?models.Team {
        if (label.len < 2) return null;
        if (label[0] != '3') return null;

        return try self.claimFromAnnexC(label);
    }

    fn claimFromAnnexC(
        self: *ThirdPlaceResolver,
        label: []const u8,
    ) !?models.Team {
        var combination_buffer: [12]u8 = undefined;
        const combination = self.qualifiedThirdPlaceCombination(&combination_buffer);

        const assignment = self.annex_c.groupForSlot(
            combination,
            label,
        ) orelse return null;

        return self.claimGroup(assignment.group);
    }

    fn qualifiedThirdPlaceCombination(
        self: *ThirdPlaceResolver,
        buffer: *[12]u8,
    ) []const u8 {
        var count: usize = 0;

        const limit = @min(self.rows.len, 8);

        var index: usize = 0;
        while (index < limit) : (index += 1) {
            const letter = groupLetter(self.rows[index].group_name) orelse continue;
            buffer[count] = letter;
            count += 1;
        }

        std.sort.block(u8, buffer[0..count], {}, charLessThan);

        return buffer[0..count];
    }

    fn claimGroup(self: *ThirdPlaceResolver, wanted_group: u8) ?models.Team {
        const limit = @min(self.rows.len, 8);

        var index: usize = 0;
        while (index < limit) : (index += 1) {
            if (self.used[index]) continue;

            const third = self.rows[index];
            const letter = groupLetter(third.group_name) orelse continue;

            if (letter != wanted_group) continue;

            self.used[index] = true;
            return third.row.team;
        }

        return null;
    }
};

pub fn roundOf32(
    allocator: std.mem.Allocator,
    io: std.Io,
    groups: []const standings.GroupTable,
) ![]RoundOf32Match {
    const third_place_rows = try standings.thirdPlaceRanking(allocator, groups);
    defer allocator.free(third_place_rows);

    const used_third_place = try allocator.alloc(bool, third_place_rows.len);
    defer allocator.free(used_third_place);

    for (used_third_place) |*used| {
        used.* = false;
    }

    var annex_c = try third_place_annex_c.load(allocator, io);
    defer annex_c.deinit(allocator);

    var resolver = ThirdPlaceResolver{
        .rows = third_place_rows,
        .used = used_third_place,
        .annex_c = &annex_c,
    };

    var matches = try allocator.alloc(RoundOf32Match, 16);

    matches[0] = try makeMatch(allocator, groups, &resolver, "M73", "06/29/2026", "03:00", "2A", "2B");
    matches[1] = try makeMatch(allocator, groups, &resolver, "M74", "06/30/2026", "04:30", "1E", "3ABCDF");
    matches[2] = try makeMatch(allocator, groups, &resolver, "M75", "06/30/2026", "09:00", "1F", "2C");
    matches[3] = try makeMatch(allocator, groups, &resolver, "M76", "06/30/2026", "01:00", "1C", "2F");

    matches[4] = try makeMatch(allocator, groups, &resolver, "M77", "07/01/2026", "05:00", "1I", "3CDFGH");
    matches[5] = try makeMatch(allocator, groups, &resolver, "M78", "07/01/2026", "01:00", "2E", "2I");
    matches[6] = try makeMatch(allocator, groups, &resolver, "M79", "07/01/2026", "09:00", "1A", "3CEFHI");
    matches[7] = try makeMatch(allocator, groups, &resolver, "M80", "07/02/2026", "00:00", "1L", "3EHIJK");

    matches[8] = try makeMatch(allocator, groups, &resolver, "M81", "07/02/2026", "08:00", "1D", "3BEFGJ");
    matches[9] = try makeMatch(allocator, groups, &resolver, "M82", "07/02/2026", "04:00", "1G", "3AEHIJ");
    matches[10] = try makeMatch(allocator, groups, &resolver, "M83", "07/03/2026", "07:00", "2K", "2L");
    matches[11] = try makeMatch(allocator, groups, &resolver, "M84", "07/03/2026", "03:00", "1H", "2J");

    matches[12] = try makeMatch(allocator, groups, &resolver, "M85", "07/03/2026", "11:00", "1B", "3EFGIJ");
    matches[13] = try makeMatch(allocator, groups, &resolver, "M86", "07/04/2026", "06:00", "1J", "2H");
    matches[14] = try makeMatch(allocator, groups, &resolver, "M87", "07/04/2026", "09:30", "1K", "3DEIJL");
    matches[15] = try makeMatch(allocator, groups, &resolver, "M88", "07/04/2026", "02:00", "2D", "2G");

    return matches;
}

pub fn freeRoundOf32(
    allocator: std.mem.Allocator,
    matches: []RoundOf32Match,
) void {
    for (matches) |match| {
        allocator.free(match.match_id);
        allocator.free(match.date);
        allocator.free(match.time);
        allocator.free(match.home.label);
        allocator.free(match.away.label);
    }

    allocator.free(matches);
}

fn makeMatch(
    allocator: std.mem.Allocator,
    groups: []const standings.GroupTable,
    resolver: *ThirdPlaceResolver,
    match_id: []const u8,
    date: []const u8,
    time: []const u8,
    home_label: []const u8,
    away_label: []const u8,
) !RoundOf32Match {
    return RoundOf32Match{
        .match_id = try allocator.dupe(u8, match_id),
        .date = try allocator.dupe(u8, date),
        .time = try allocator.dupe(u8, time),
        .home = try resolveSeed(
            allocator,
            groups,
            resolver,
            home_label,
        ),
        .away = try resolveSeed(
            allocator,
            groups,
            resolver,
            away_label,
        ),
    };
}

fn resolveSeed(
    allocator: std.mem.Allocator,
    groups: []const standings.GroupTable,
    resolver: *ThirdPlaceResolver,
    label: []const u8,
) !Seed {
    return Seed{
        .label = try allocator.dupe(u8, label),
        .team = if (isConditionalThirdPlaceSeed(label))
            try resolver.claim(label)
        else
            findTeamBySeed(groups, label),
    };
}

fn isConditionalThirdPlaceSeed(label: []const u8) bool {
    return label.len > 2 and label[0] == '3';
}

fn findTeamBySeed(
    groups: []const standings.GroupTable,
    label: []const u8,
) ?models.Team {
    if (label.len != 2) {
        return null;
    }

    const rank_char = label[0];
    const group_char = label[1];

    if (rank_char < '1' or rank_char > '3') {
        return null;
    }

    const wanted_rank: i16 = @intCast(rank_char - '0');

    for (groups) |group| {
        const group_char_from_name = groupLetter(group.name) orelse continue;

        if (group_char_from_name != group_char) {
            continue;
        }

        for (group.rows) |row| {
            if (row.rank == wanted_rank) {
                return row.team;
            }
        }
    }

    return null;
}

fn groupLetter(group_name: []const u8) ?u8 {
    const marker = "Group ";
    const index = std.mem.indexOf(u8, group_name, marker) orelse return null;
    const letter_index = index + marker.len;

    if (letter_index >= group_name.len) {
        return null;
    }

    return group_name[letter_index];
}

fn charLessThan(_: void, left: u8, right: u8) bool {
    return left < right;
}
