const std = @import("std");

const Error = @import("Error.zig");
const Location = @import("Location.zig");

const Self = @This();

memory: std.heap.ArenaAllocator,
errors: std.ArrayListUnmanaged(Error) = .{},

pub fn init(allocator: std.mem.Allocator) Self {
    return Self{
        .memory = std.heap.ArenaAllocator.init(allocator),
    };
}

pub fn deinit(self: *Self) void {
    self.memory.deinit();
    self.* = undefined;
}

pub fn print(self: Self, writer: anytype) !void {
    for (self.errors.items) |err| {
        const source = err.location.source orelse "???";
        try writer.print("{s}:{d}:{d}: {s}: {s}\n", .{
            source,
            err.location.line,
            err.location.column,
            @tagName(err.level),
            err.message,
        });
    }
}

pub fn emit(self: *Self, location: Location, level: Error.Level, comptime fmt: []const u8, args: anytype) !void {
    const allocator = self.memory.allocator();

    const str = try std.fmt.allocPrintZ(allocator, fmt, args);
    errdefer allocator.free(str);

    try self.errors.append(allocator, Error{
        .location = location,
        .level = level,
        .message = str,
    });
}

pub fn hasErrors(self: Self) bool {
    for (self.errors.items) |err| {
        if (err.level == .@"error")
            return true;
    }
    return false;
}

pub fn hasWarnings(self: Self) bool {
    for (self.errors.items) |err| {
        if (err.level == .warning)
            return true;
    }
    return false;
}
