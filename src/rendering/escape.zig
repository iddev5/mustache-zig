const std = @import("std");
const Allocator = std.mem.Allocator;
const trait = std.meta.trait;

const context = @import("context.zig");
const Escape = context.Escape;

const testing = std.testing;
const assert = std.debug.assert;

pub fn escapeWrite(
    out_writer: anytype,
    value: []const u8,
    escape: Escape,
) @TypeOf(out_writer).Error!usize {
    switch (escape) {
        .Unescaped => {
            try out_writer.writeAll(value);
            return value.len;
        },

        .Escaped => {
            const @"null" = '\x00';
            const html_null: []const u8 = "\u{fffd}";

            var index: usize = 0;
            var written_bytes: usize = 0;

            for (value) |char, char_index| {
                const replace = switch (char) {
                    '"' => "&quot;",
                    '\'' => "&#39;",
                    '&' => "&amp;",
                    '<' => "&lt;",
                    '>' => "&gt;",
                    @"null" => html_null,
                    else => continue,
                };

                if (char_index > index) {
                    const slice = value[index..char_index];
                    try out_writer.writeAll(slice);
                    written_bytes += slice.len;
                }

                try out_writer.writeAll(replace);
                written_bytes += replace.len;

                index = char_index + 1;
                if (index == value.len) break;
            }

            if (index < value.len) {
                const slice = value[index..];
                try out_writer.writeAll(slice);
                written_bytes += slice.len;
            }

            return written_bytes;
        },
    }
}

test "write" {
    try write("&gt;abc", ">abc", .Escaped);
    try write("abc&lt;", "abc<", .Escaped);
    try write("&gt;abc&lt;", ">abc<", .Escaped);
    try write("ab&amp;cd", "ab&cd", .Escaped);
    try write("&gt;ab&amp;cd", ">ab&cd", .Escaped);
    try write("ab&amp;cd&lt;", "ab&cd<", .Escaped);
    try write("&gt;ab&amp;cd&lt;", ">ab&cd<", .Escaped);

    try write(">ab&cd<", ">ab&cd<", .Unescaped);
}

fn write(expected: []const u8, value: []const u8, escape: Escape) !void {
    const allocator = testing.allocator;
    var list = std.ArrayList(u8).init(allocator);
    defer list.deinit();

    var written_bytes = try escapeWrite(list.writer(), value, escape);
    try testing.expectEqualStrings(expected, list.items);
    try testing.expectEqual(expected.len, written_bytes);
}
