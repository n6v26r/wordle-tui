const std = @import("std");

const Wordle = @import("wordle").Wordle;
const zz = @import("zigzag");
pub const uppercase = zz.transforms.uppercase;

const Settings = struct {
    word: []const u8,
    max_guesses: u32,
    wordlist: ?*std.StringHashMap(bool),
};

const Model = struct {
    pub const Msg = union(enum) {
        key: zz.KeyEvent,
    };

    wordle: Wordle,
    settings: Settings,

    curr_word: []u8,
    curr_word_len: u32 = 0,

    fn addLetter(self: *Model, key: zz.KeyEvent) !void {
        if (self.wordle.hasEnded())
            return;
        if (self.curr_word_len == self.curr_word.len)
            return error.WordFull;

        const c = std.ascii.toUpper(@as(u8, @truncate(key.key.toChar().?)));
        self.curr_word[self.curr_word_len] = c;
        self.curr_word_len += 1;
    }

    fn delLetter(self: *Model) !void {
        if (self.wordle.hasEnded())
            return;
        if (self.curr_word_len == 0)
            return error.WordEmpty;

        self.curr_word_len -= 1;
        self.curr_word[self.curr_word_len] = 0;
    }

    fn clearLetters(self: *Model) void {
        while (self.curr_word_len > 0) {
            self.curr_word_len -= 1;
            self.curr_word[self.curr_word_len] = 0;
        }
    }

    fn reportError(e: anyerror) noreturn {
        @panic(@errorName(e));
    }

    pub fn update(self: *Model, msg: Msg, _: *zz.Context) zz.Cmd(Msg) {
        switch (msg) {
            .key => |k| switch (k.key) {
                .escape => return .quit,
                .backspace => self.delLetter() catch {},
                .enter => {
                    if (self.wordle.hasEnded())
                        return .none;
                    if (self.curr_word_len == self.wordle.word.len) {
                        self.wordle.sendWord(self.curr_word) catch |e| switch (e) {
                            error.NotInWordList => {
                                return .none;
                            },
                            else => {},
                        };
                        self.clearLetters();
                    }
                },
                .char => self.addLetter(msg.key) catch {},
                else => {},
            },
        }
        return .none;
    }

    pub fn init(self: *Model, ctx: *zz.Context) zz.Cmd(Msg) {
        self.wordle = Wordle.init(
            ctx.persistent_allocator,
            self.settings.word,
            self.settings.max_guesses,
            self.settings.wordlist,
        ) catch |e|
            reportError(e);

        self.curr_word = self.wordle.alloc.alloc(u8, self.settings.word.len) catch |e| reportError(e);
        @memset(self.curr_word, 0);

        return .none;
    }

    pub fn deinit(self: *Model) void {
        self.wordle.alloc.free(self.curr_word);
        self.wordle.deinit();
    }

    pub fn renderChar(alloc: std.mem.Allocator, char: Wordle.AnnotatedChar) []const u8 {
        const style: zz.Style = .{
            .foreground = switch (char.match) {
                .unknown => .none,
                .none => zz.Color.black(),
                .partial => zz.Color.blue(),
                .ok => zz.Color.green(),
            },
        };
        const border: zz.Style = .{
            .border_style = zz.Border.rounded,
            .border_bg = .none,
            .border_fg = switch (char.match) {
                .unknown => .none,
                .none => zz.Color.black(),
                .partial => zz.Color.blue(),
                .ok => zz.Color.green(),
            },
            .border_sides = .all,
        };
        const text = std.fmt.allocPrint(alloc, " {c} ", .{char.char}) catch "!";
        const colored_text = style.render(alloc, text) catch text;
        return border.render(alloc, colored_text[0 .. colored_text.len - 1]) catch colored_text;
    }

    pub fn renderBlank(alloc: std.mem.Allocator) []const u8 {
        const style: zz.Style = .{
            .background = .none,
            .foreground = zz.Color.black(),
        };

        const border: zz.Style = .{
            .border_style = zz.Border.rounded,
            .border_bg = .none,
            .border_fg = zz.Color.brightBlack(),
            .border_sides = .all,
        };
        const text = std.fmt.allocPrint(alloc, "   ", .{}) catch "!";
        const colored_text = style.render(alloc, text) catch text;
        return border.render(alloc, colored_text[0 .. colored_text.len - 1]) catch colored_text;
    }

    pub fn renderSpace() []const u8 {
        return "   \n   \n   ";
    }

    fn joinV(alloc: std.mem.Allocator, elems: [2][]const u8) ![]const u8 {
        if (elems[0].len == 0)
            return elems[1];
        if (elems[1].len == 0)
            return elems[0];

        return try zz.joinVertical(alloc, &elems);
    }
    fn joinH(alloc: std.mem.Allocator, elems: [2][]const u8) ![]const u8 {
        if (elems[0].len == 0)
            return elems[1];
        if (elems[1].len == 0)
            return elems[0];

        return try zz.joinHorizontal(alloc, &elems);
    }

    fn renderPlayedWords(self: *Model, alloc: std.mem.Allocator) ![]const u8 {
        var played_words_text: []const u8 = "";
        for (0..self.wordle.guesslen) |i| {
            var row: []const u8 = "";
            for (0..self.wordle.word.len) |j| {
                const c = renderChar(alloc, self.wordle.guess[i][j]);
                row = try joinH(alloc, .{ row, c });
            }
            played_words_text = try joinV(alloc, .{ played_words_text, row });
        }

        return played_words_text;
    }

    fn renderCurrWord(self: *Model, alloc: std.mem.Allocator) ![]const u8 {
        var curr_word_text: []const u8 = "";
        if (self.wordle.guesslen < self.wordle.max_guesses) {
            for (0..self.curr_word_len) |i| {
                const c = renderChar(alloc, .{ .char = self.curr_word[i], .match = .unknown });
                curr_word_text = try joinH(alloc, .{ curr_word_text, c });
            }
            for (self.curr_word_len..self.curr_word.len) |_| {
                const c = renderBlank(alloc);
                curr_word_text = try joinH(alloc, .{ curr_word_text, c });
            }
        }
        return curr_word_text;
    }

    fn renderBlankLines(self: *Model, alloc: std.mem.Allocator) ![]const u8 {
        var empty_lines_text: []const u8 = "";
        if (self.wordle.guesslen < self.wordle.max_guesses) {
            for (self.wordle.guesslen..self.wordle.max_guesses - 1) |_| {
                var row: []const u8 = "";
                for (0..self.wordle.word.len) |_| {
                    const c: []const u8 = renderBlank(alloc);
                    row = try joinH(alloc, .{ row, c });
                }
                empty_lines_text = try joinV(alloc, .{ empty_lines_text, row });
            }
        }
        return empty_lines_text;
    }

    fn renderEndGame(self: *Model, alloc: std.mem.Allocator) ![]const u8 {
        if (!self.wordle.hasEnded()) return "";

        const style: zz.Style = .{
            .foreground = zz.Color.red(),
        };
        var text: []const u8 = undefined;

        if (self.wordle.solved) {
            const guesses_text = try style.render(alloc, try std.fmt.allocPrint(alloc, "{d}", .{self.wordle.guesslen}));

            text = try std.fmt.allocPrint(alloc, "Solved in {s} tries", .{guesses_text[0 .. guesses_text.len - 1]});
        } else {
            const word_text = try style.render(alloc, try std.fmt.allocPrint(alloc, "{s}", .{self.wordle.word}));
            text = try std.fmt.allocPrint(alloc, "Word was {s}", .{word_text});
        }

        return text;
    }

    fn renderWordleTable(self: *Model, alloc: std.mem.Allocator) ![]const u8 {
        var end_text = try self.renderEndGame(alloc);

        const played_words_text = try self.renderPlayedWords(alloc);
        const curr_word_text = try self.renderCurrWord(alloc);
        const typed_text = try joinV(alloc, .{ played_words_text, curr_word_text });
        const empty_lines = try self.renderBlankLines(alloc);

        var table = try joinV(alloc, .{ typed_text, empty_lines });

        end_text = try zz.place.place(alloc, 5 * self.wordle.word.len, 1, .center, .top, end_text);
        table = try joinV(alloc, .{ end_text, table });

        return table;
    }

    fn renderKeyboard(self: *Model, alloc: std.mem.Allocator) ![]const u8 {
        const query: [3][]const u8 = .{ "QWERTYUIOP", "ASDFGHJKL", "ZXCVBNM" };
        var keyboard: []const u8 = "";
        for (0..query.len) |i| {
            var row: []const u8 = "";
            if (i == 1)
                row = try joinH(alloc, .{ row, renderSpace() });
            if (i == 2) {
                row = try joinH(alloc, .{ row, renderSpace() });
                row = try joinH(alloc, .{ row, renderSpace() });
                row = try joinH(alloc, .{ row, "  " });
            }
            for (0..query[i].len) |j| {
                const c = renderChar(alloc, .{ .char = query[i][j], .match = self.wordle.keyboard[query[i][j]] });
                row = try joinH(alloc, .{ row, c });
            }
            keyboard = try joinV(alloc, .{ keyboard, row });
        }

        return keyboard;
    }

    pub fn view(self: *Model, ctx: *zz.Context) []const u8 {
        const table = self.renderWordleTable(ctx.allocator) catch |e| reportError(e);
        const spacer = renderSpace();
        var keyboard = self.renderKeyboard(ctx.allocator) catch |e| reportError(e);
        keyboard = zz.place.place(ctx.allocator, ctx.width, 1, .center, .top, keyboard) catch |e| reportError(e);

        var text = joinV(ctx.allocator, .{ table, spacer }) catch |e| reportError(e);
        text = zz.place.place(ctx.allocator, ctx.width, 1, .center, .top, text) catch |e| reportError(e);
        text = joinV(ctx.allocator, .{ text, keyboard }) catch |e| reportError(e);

        const centered = zz.place.place(ctx.allocator, ctx.width, ctx.height, .center, .middle, text) catch |e| reportError(e);
        return centered;
    }
};

pub fn run(alloc: std.mem.Allocator, s: Settings) !void {
    var program = try zz.Program(Model).initWithOptions(alloc, .{});
    program.model.settings = s;
    defer program.deinit();
    try program.run();
}
