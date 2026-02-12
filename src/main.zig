const std = @import("std");
const tui = @import("tui.zig");
const rand = std.Random;

const wordlist5_raw = @embedFile("wordlist5.txt");
const pickword5_raw = @embedFile("pickword5.txt");

pub fn constructWordList(alloc: std.mem.Allocator, wordlist: []const u8) !std.StringHashMap(bool) {
    var hashmap = std.StringHashMap(bool).init(alloc);
    var n: u32 = 0;
    while (n * 6 < wordlist.len) : (n += 1) {
        try hashmap.put(wordlist[n * 6 .. (n + 1) * 6 - 1], true);
    }
    return hashmap;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{
        .thread_safe = true,
    }){};
    defer std.debug.print("Memory Leaks: {}\n", .{gpa.deinit()});
    const alloc = gpa.allocator();

    const seed = @as(u64, @truncate(@as(u128, @bitCast(std.time.nanoTimestamp()))));
    var prng = rand.DefaultPrng.init(seed);
    const rnd = prng.random();
    const n = rnd.int(u32) % pickword5_raw.len / 6;

    const word = pickword5_raw[n * 6 .. (n + 1) * 6 - 1];

    var wordlist = try constructWordList(alloc, wordlist5_raw);
    defer wordlist.deinit();

    try tui.run(alloc, .{
        .word = word,
        .max_guesses = 6,
        .wordlist = &wordlist,
    });
}
