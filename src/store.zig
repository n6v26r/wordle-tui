const kf = @import("known-folders");
const std = @import("std");
const getDate = @import("date.zig").currDate;

pub const Store = struct {
    data_dir: std.fs.Dir,

    pub fn init(alloc: std.mem.Allocator) !Store {
        const data_dir_path = try kf.getPath(alloc, .data);
        defer if (data_dir_path) |p| alloc.free(p);

        if (data_dir_path == null) return error.NoDirPath;

        var data_dir = try std.fs.openDirAbsolute(data_dir_path.?, .{});
        try data_dir.makePath("wordle");

        return .{ .data_dir = data_dir };
    }

    pub fn deinit(self: *Store) void {
        self.data_dir.close();
    }

    pub fn saveDailyProgress(self: *Store, bytes: [][]u8) !void {
        var file = try self.data_dir.createFile("wordle/daily", .{ .truncate = true });
        defer file.close();

        if (bytes.len == 0) {
            return;
        }
        var buf: [128]u8 = undefined;
        var writer = file.writer(buf[0..]);
        _ = try writer.interface.write(getDate());
        for (0..bytes.len) |i| {
            _ = try writer.interface.write(bytes[i]);
        }
        try writer.interface.flush();
    }

    pub fn readDailyProgress(self: *Store, alloc: std.mem.Allocator) !?[][]u8 {
        var file = try self.data_dir.openFile("wordle/daily", .{});
        defer file.close();

        var buf: [128]u8 = undefined;
        var reader = file.reader(buf[0..]);
        const content = try reader.interface.readAlloc(alloc, try file.getEndPos());
        const date = getDate();
        defer alloc.free(content);

        if (content.len < date.len) return null;
        if (std.mem.eql(u8, content[0..date.len], date)) {
            const words_len = content.len - date.len;
            if (words_len % 5 != 0) return null;

            const word_cnt = words_len / 5;
            var bytes = try alloc.alloc([]u8, word_cnt);
            var allocated: usize = 0;
            errdefer {
                for (0..allocated) |i| {
                    alloc.free(bytes[i]);
                }
                alloc.free(bytes);
            }
            for (0..word_cnt) |i| {
                bytes[i] = try alloc.alloc(u8, 5);
                allocated += 1;
                @memcpy(bytes[i], content[date.len + i * 5 .. date.len + (i + 1) * 5]);
            }
            return bytes;
        }
        return null;
    }
};
