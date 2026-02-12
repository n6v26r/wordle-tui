const std = @import("std");
const tui = @import("tui.zig");
const rand = std.Random;

const wordlist5 = @embedFile("wordlist.txt");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{
        .thread_safe = true,
    }){};
    defer std.debug.print("Memory Leaks: {}\n", .{gpa.deinit()});
    const alloc = gpa.allocator();

    const seed = @as(u64, @truncate(@as(u128, @bitCast(std.time.nanoTimestamp()))));
    var prng = rand.DefaultPrng.init(seed);
    const rnd = prng.random();
    const n = rnd.int(u32) % wordlist5.len / 6;

    const word = tui.uppercase(alloc, wordlist5[n * 6 .. (n + 1) * 6 - 1]);
    defer alloc.free(word);

    try tui.run(alloc, .{ .word = word, .max_guesses = 6 });
}
