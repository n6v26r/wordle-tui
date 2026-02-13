const std = @import("std");
const curl = @import("curl");
const json = std.json;
const currDate = @import("date.zig").currDate;

const URL = "https://www.nytimes.com/svc/wordle/v2/{s}.json";
var buffer: [1024]u8 = undefined;

const WordleData = struct {
    id: u32,
    solution: []const u8,
    print_date: []const u8,
    days_since_launch: u32,
    editor: []const u8,
};

var data: WordleData = undefined;

pub fn getWordle(alloc: std.mem.Allocator, date: []const u8) ![]const u8 {
    const url = try std.fmt.allocPrint(alloc, URL, .{date});
    const url_c_str = try std.mem.Allocator.dupeZ(alloc, u8, url);

    const ca_bundle = try curl.allocCABundle(alloc);
    defer ca_bundle.deinit();

    const easy = try curl.Easy.init(.{ .ca_bundle = ca_bundle });
    defer easy.deinit();

    var writer = std.io.Writer.fixed(&buffer);
    const resp = try easy.fetch(url_c_str, .{ .writer = &writer });
    if (resp.status_code != 200)
        return error.FetchFailed;

    const parsed = try json.parseFromSlice(WordleData, alloc, writer.buffered(), .{});
    defer parsed.deinit();

    data = parsed.value;
    return data.solution;
}

pub fn getWordleToday(alloc: std.mem.Allocator) ![]const u8 {
    const date = currDate();
    return try getWordle(alloc, date);
}
