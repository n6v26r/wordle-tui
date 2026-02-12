const std = @import("std");
const rand = std.Random;

const wordlist5_raw = @embedFile("wordlist5.txt");
const pickword5_raw = @embedFile("pickword5.txt");

pub fn constructWordList(alloc: std.mem.Allocator) !std.StringHashMap(bool) {
    var hashmap = std.StringHashMap(bool).init(alloc);
    var n: u32 = 0;
    while (n * 6 < wordlist5_raw.len) : (n += 1) {
        try hashmap.put(wordlist5_raw[n * 6 .. (n + 1) * 6 - 1], true);
    }
    return hashmap;
}

var prng: rand.DefaultPrng = undefined;

pub fn initRand() void {
    const seed = @as(u64, @truncate(@as(u128, @bitCast(std.time.nanoTimestamp()))));
    prng = rand.DefaultPrng.init(seed);
}

pub fn getRandWord() []const u8 {
    const rnd = prng.random();
    const n = rnd.int(u32) % pickword5_raw.len / 6;
    return pickword5_raw[n * 6 .. (n + 1) * 6 - 1];
}
