const std = @import("std");
const process = std.process;

pub fn main() anyerror!void {
    // TODO: Revisit memory allocator strategy. Using arena for now
    // But how does it work? Is it appropriate here, elsewhere?
    var arena  = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = &arena.allocator;

    const ledgerFile = try process.getEnvVarOwned(allocator, "LEDGER_FILE");

    std.log.info("LEDGER_FILE: {s}", .{ledgerFile});
}
