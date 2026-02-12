const std = @import("std");

pub const Wordle = struct {
    const AlphabetSize = std.math.maxInt(u8) + 1;

    pub const KeyState = enum {
        unknown,
        partial,
        ok,
        none,
    };

    pub const AnnotatedChar = struct {
        char: u8,
        match: KeyState,
    };

    alloc: std.mem.Allocator = undefined,
    max_guesses: u32 = undefined,
    word: []const u8 = undefined,
    guess: [][]AnnotatedChar = undefined,
    guesslen: u32 = 0,
    keyboard: [AlphabetSize]KeyState = undefined,
    wordfrecv: [AlphabetSize]u32 = std.mem.zeroes(@FieldType(@This(), "wordfrecv")),

    fn buildFrecv(self: *Wordle) void {
        for (0..self.word.len) |i| {
            self.wordfrecv[self.word[i]] += 1;
        }
        @memset(self.keyboard[0..], .unknown);
    }

    pub fn init(
        alloc: std.mem.Allocator,
        word: []const u8,
        max_guesses: u32,
    ) !@This() {
        var self: @This() = .{};
        self.alloc = alloc;
        self.max_guesses = max_guesses;
        self.word = word;

        @memset(self.keyboard[0..], .unknown);
        self.guess = try alloc.alloc([]AnnotatedChar, self.max_guesses);
        for (0..self.max_guesses) |i|
            self.guess[i] = try alloc.alloc(AnnotatedChar, self.word.len);

        self.buildFrecv();
        return self;
    }

    pub fn hasEnded(self: *Wordle) bool {
        return self.guesslen == self.max_guesses;
    }

    pub fn sendWord(self: *Wordle, word: []const u8) !void {
        if (self.guesslen == self.max_guesses)
            return error.NoGuessesLeft;
        if (word.len != self.word.len)
            return error.InvalidLen;

        var frecv: [AlphabetSize]u32 = self.wordfrecv;

        for (0..self.word.len) |i| {
            self.guess[self.guesslen][i] = .{ .char = word[i], .match = .none };
            self.keyboard[self.guess[self.guesslen][i].char] = .none;
            if (self.word[i] == word[i]) {
                if (frecv[word[i]] > 0)
                    frecv[word[i]] -= 1;
                self.guess[self.guesslen][i].match = .ok;
                self.keyboard[self.guess[self.guesslen][i].char] = .ok;
                continue;
            }
        }

        for (0..self.word.len) |i| {
            if (self.guess[self.guesslen][i].match == .none and frecv[word[i]] > 0) {
                frecv[word[i]] -= 1;
                self.guess[self.guesslen][i].match = .partial;
                self.keyboard[self.guess[self.guesslen][i].char] = .partial;
                continue;
            }
        }

        self.guesslen += 1;
    }

    pub fn deinit(self: *Wordle) void {
        for (0..self.max_guesses) |i|
            self.alloc.free(self.guess[i]);
        self.alloc.free(self.guess);
    }
};
