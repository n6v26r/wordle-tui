const std = @import("std");
const ctime = @cImport(@cInclude("time.h"));

var dt_str_buf: [40]u8 = undefined;

pub fn currDate() []const u8 {
    const t = ctime.time(null);
    const lt = ctime.localtime(&t);
    const format = "%Y-%m-%d";
    const dt_str_len = ctime.strftime(&dt_str_buf, dt_str_buf.len, format, lt);
    return dt_str_buf[0..dt_str_len];
}
