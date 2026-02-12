const std = @import("std");
const Wordle = @import("wordle").Wordle;
const tui = @import("tui.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{
        .thread_safe = true,
    }){};
    defer std.debug.print("Memory Leaks: {}\n", .{gpa.deinit()});
    const alloc = gpa.allocator();

    try tui.run(alloc, .{ .word = "ROBOT", .max_guesses = 6 });
}
