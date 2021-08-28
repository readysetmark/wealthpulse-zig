const std = @import("std");

// Public 

pub fn scanTokens(source: []const u8) void {
    var priceScanner = Scanner{
        .source = source,
    };
    priceScanner.scanTokens();
}


// Private

const PriceSentinelCharacter = 'P';

const TokenType = enum {
    PriceSentinel,
    Date,
    Commodity,
    Amount,
    LineBreak,
    Eof,
};

const Token = struct {
    token_type: TokenType,
    text: []const u8,
    line: usize,
};

// TODO: Set up some unit tests for good and bad Price strings!
// TODO: Need a return type!

const Scanner = struct {
    source: []const u8,
    // TODO: need tokens list that we build up
    current: u8 = undefined,
    token_start: usize = 0,
    index: usize = 0,
    line: usize = 1,

    fn scanTokens(self: *Scanner) void {
        // TODO: Need better error handling
        std.log.debug("Parsing text (length {}): {s}", .{self.source.len, self.source});

        while (self.index < self.source.len) {
            // Start of new token
            self.token_start = self.index;

            // TODO: wrap this in a scanToken() ??
            self.advance();
            
            if (self.current == PriceSentinelCharacter) {
                self.price();
            }
            else {
                std.log.err("(Line {}) Expecting '{c}' but found: {}", .{self.line, PriceSentinelCharacter, self.current});
            }

            // Jump to the end to short-circuit parsing the rest!
            self.index = self.source.len;
        }

        std.log.debug("token: {}", .{TokenType.Eof});
    }

    fn advance(self: *Scanner) void {
        self.current = self.source[self.index];
        self.index += 1;
    }

    fn expect(self: *Scanner, character: u8) void {
        if (self.current == character) {
            self.advance();
        }
        else {
            std.log.err("(Line {}) Expecting '{c}' but found: {c}", .{self.line, character, self.current});
        }
    }

    fn price(self: *Scanner) void {
        std.log.debug("token: {} {s}", .{TokenType.PriceSentinel, self.source[self.token_start..self.index]});
        self.advance();
        self.expect(' ');
        self.date();
        self.expect(' ');
    }

    fn date(self: *Scanner) void {
        // yyyy-MM-dd
        self.token_start = self.index - 1;
        comptime var i = 0;    
        inline while (i < 4) : (i += 1) {
            self.number();
        }
        self.expect('-');
        i = 0;
        inline while (i < 2) : (i += 1) {
            self.number();
        }
        self.expect('-');
        i = 0;
        inline while (i < 2) : (i += 1) {
            self.number();
        }
        std.log.debug("token: {} {s}", .{TokenType.Date, self.source[self.token_start..self.index]});
    }

    fn number(self: *Scanner) void {
        if (self.current >= '0' and self.current <= '9') {
            self.advance();
        }
        else {
            std.log.err("(Line {}) Expecting number but found: {c}", .{self.line, self.current});
        }
    }
};
