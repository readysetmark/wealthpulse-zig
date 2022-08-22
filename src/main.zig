const std = @import("std");
const scanner = @import("./scanner.zig");
const ArenaAllocator = std.heap.ArenaAllocator;
// const process = std.process;
// const fs = std.fs;

// This will be useful later, but for now I'll be testing with smaller samples

// pub fn main() anyerror!void {
//     // TODO: Revisit memory allocator strategy. Using arena for now
//     // But how does it work? Is it appropriate here, elsewhere?
//     var arena  = std.heap.ArenaAllocator.init(std.heap.page_allocator);
//     defer arena.deinit();
//     const allocator = &arena.allocator;

//     // Get path to ledger file from environment variable
//     const ledgerFilePath = try process.getEnvVarOwned(allocator, "LEDGER_FILE");
//     std.log.info("LEDGER_FILE: {s}", .{ledgerFilePath});

//     // Open the file
//     const ledgerFile = try fs.openFileAbsolute(ledgerFilePath, fs.File.OpenFlags{
//         .read = true,
//         .write = false,
//         .lock = fs.File.Lock.None,
//         });
//     defer ledgerFile.close();

//     // Read all data from file
//     // TODO: Should do this as a buffer/stream instead?
//     const data = try ledgerFile.readToEndAlloc(allocator, 100000000);

//     std.log.info("Opened file and read {} bytes", .{data.len});
// }


pub fn main() anyerror!void {
    var arena  = ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    try scanner.scanTokens(allocator, "P 2021-08-28 \"WP\" $25.4400\r\nP 2021-08-29 \"WP\" $26.2300\r\nP 2022-08-21 \"WP\" $24.2800\r\n");
}