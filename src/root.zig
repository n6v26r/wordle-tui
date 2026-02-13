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
    guess_len: u32 = 0,
    keyboard: [AlphabetSize]KeyState = undefined,
    wordfrecv: [AlphabetSize]u32 = undefined,
    solved: bool = false,
    wordlist: ?*std.StringHashMap(bool) = null,

    fn buildFrecv(self: *Wordle) void {
        @memset(self.wordfrecv[0..], 0);
        for (0..self.word.len) |i| {
            self.wordfrecv[self.word[i]] += 1;
        }
        @memset(self.keyboard[0..], .unknown);
    }

    pub fn getPlayedWords(self: *Wordle) ![][]u8 {
        const played_words: [][]u8 = try self.alloc.alloc([]u8, self.guess_len + 1);
        for (0..self.guess_len) |i| {
            played_words[i] = try self.alloc.alloc(u8, self.word.len);
            for (0..self.word.len) |j| {
                played_words[i][j] = self.guess[i][j].char;
            }
        }

        played_words[self.guess_len] = try self.alloc.alloc(u8, self.word.len);
        @memcpy(played_words[self.guess_len], self.word);
        return played_words;
    }

    pub fn setWord(self: *Wordle, word: []const u8) void {
        self.word = word;
        self.buildFrecv();
    }

    pub fn init(
        alloc: std.mem.Allocator,
        word: []const u8,
        max_guesses: u32,
        wordlist: ?*std.StringHashMap(bool),
    ) !@This() {
        var self: @This() = .{};
        self.alloc = alloc;
        self.max_guesses = max_guesses;
        self.word = word;
        self.wordlist = wordlist;

        @memset(self.keyboard[0..], .unknown);
        self.guess = try alloc.alloc([]AnnotatedChar, self.max_guesses);
        for (0..self.max_guesses) |i|
            self.guess[i] = try alloc.alloc(AnnotatedChar, self.word.len);

        self.buildFrecv();
        return self;
    }

    pub fn hasEnded(self: *Wordle) bool {
        return self.guess_len == self.max_guesses or self.solved;
    }

    pub fn sendWord(self: *Wordle, word: []const u8) !void {
        if (self.guess_len == self.max_guesses)
            return error.NoGuessesLeft;
        if (word.len != self.word.len)
            return error.InvalidLen;

        if (self.wordlist) |w| {
            if (!w.contains(word))
                return error.NotInWordList;
        }

        var frecv: [AlphabetSize]u32 = self.wordfrecv;

        var matched: u32 = 0;
        for (0..self.word.len) |i| {
            self.guess[self.guess_len][i] = .{ .char = word[i], .match = .none };
            if (self.keyboard[word[i]] == .unknown)
                self.keyboard[word[i]] = .none;
            if (self.word[i] == word[i]) {
                if (frecv[word[i]] > 0)
                    frecv[word[i]] -= 1;
                self.guess[self.guess_len][i].match = .ok;
                self.keyboard[word[i]] = .ok;
                matched += 1;
                continue;
            }
        }
        if (matched == self.word.len)
            self.solved = true;

        for (0..self.word.len) |i| {
            if (self.guess[self.guess_len][i].match == .none and frecv[word[i]] > 0) {
                frecv[word[i]] -= 1;
                self.guess[self.guess_len][i].match = .partial;
                if (self.keyboard[word[i]] != .ok)
                    self.keyboard[word[i]] = .partial;
                continue;
            }
        }

        self.guess_len += 1;
    }

    pub fn deinit(self: *Wordle) void {
        for (0..self.max_guesses) |i|
            self.alloc.free(self.guess[i]);
        self.alloc.free(self.guess);
    }
};
