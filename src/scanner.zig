const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

// Public 

// TODO: Set up some unit tests for good and bad Price strings!
// TODO: Need a return type!
pub fn scanTokens(allocator: *Allocator, source: []const u8) !void {
    var priceScanner = Scanner{
        .source = source,
        .tokens = ArrayList(Token).init(allocator),
    };
    try priceScanner.scanTokens();
}


// Private

const PriceSentinelCharacter = 'P';

const TokenType = enum {
    PriceSentinel,
    DateYear,
    DateMonth,
    DateDay,
    Symbol,
    Quantity,
    LineBreak,
    EndOfFile,
};

const Token = struct {
    token_type: TokenType,
    text: ?[]const u8,
    line: usize,

    fn printDebug(self: *const Token) void {
        // TODO: can I use std.fmt.format to produce a string instead?
        if (self.text == null) {
            std.log.debug("Token: (Line {}) {}", .{self.line, self.token_type});
        } else {
            std.log.debug("Token: (Line {}) {} '{s}'", .{self.line, self.token_type, self.text});
        }
    }
};

const Scanner = struct {
    source: []const u8,
    tokens: ArrayList(Token),
    current: u8 = undefined,
    token_start: usize = 0,
    index: usize = 0,
    line: usize = 1,

    fn scanTokens(self: *Scanner) !void {
        // TODO: Need better error handling
        std.log.debug("Parsing text (length {}): {s}", .{self.source.len, self.source});

        while (self.index < self.source.len) {
            // Start of new token
            self.token_start = self.index;

            // TODO: wrap this in a scanToken() ??
            self.advance();
            
            if (self.current == PriceSentinelCharacter) {
                try self.price();
            } else {
                std.log.err("(Line {}) Expecting '{c}' but found: {}", .{self.line, PriceSentinelCharacter, self.current});
            }

            // Jump to the end to short-circuit parsing the rest!
            self.index = self.source.len;
        }

        // TODO: Do I even need an EOF token?
        try self.tokens.append(Token{
            .token_type = TokenType.EndOfFile,
            .text = null,
            .line = self.line,
        });

        for (self.tokens.items) |token| {
            token.printDebug();
        }
    }

    fn advance(self: *Scanner) void {
        self.current = self.source[self.index];
        self.index += 1;
    }

    fn expect(self: *Scanner, character: u8) void {
        if (self.current == character) {
            self.advance();
        } else {
            std.log.err("(Line {}) Expecting '{c}' but found: {c}", .{self.line, character, self.current});
        }
    }

    fn price(self: *Scanner) !void {
        try self.tokens.append(Token{
            .token_type = TokenType.PriceSentinel,
            .text = self.source[self.token_start..self.index],
            .line = self.line,
        });
        self.advance();
        self.expect(' ');
        try self.date();
        self.expect(' ');
    }

    fn date(self: *Scanner) !void {
        // yyyy-MM-dd
        self.token_start = self.index - 1;
        comptime var i = 0;    
        inline while (i < 4) : (i += 1) {
            self.number();
        }
        try self.tokens.append(Token{
            .token_type = TokenType.DateYear,
            .text = self.source[self.token_start..self.index-1],
            .line = self.line,
        });

        self.expect('-');
        self.token_start = self.index - 1;
        i = 0;
        inline while (i < 2) : (i += 1) {
            self.number();
        }
        try self.tokens.append(Token{
            .token_type = TokenType.DateMonth,
            .text = self.source[self.token_start..self.index-1],
            .line = self.line,
        });

        self.expect('-');
        self.token_start = self.index - 1;
        i = 0;
        inline while (i < 2) : (i += 1) {
            self.number();
        }
        try self.tokens.append(Token{
            .token_type = TokenType.DateDay,
            .text = self.source[self.token_start..self.index-1],
            .line = self.line,
        });
    }

    fn number(self: *Scanner) void {
        if (self.current >= '0' and self.current <= '9') {
            self.advance();
        } else {
            std.log.err("(Line {}) Expecting number but found: {c}", .{self.line, self.current});
        }
    }
};
