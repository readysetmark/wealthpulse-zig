const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

// Public 

// TODO: Parse a series of price entries!
// TODO: Refactoring / simplifying!
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
        if (self.index >= self.source.len)
        {
            self.current = 0;
            self.index = self.source.len + 1;
        } else {
            self.current = self.source[self.index];
            self.index += 1;
        }
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
        try self.symbol();
        self.expect(' ');
        try self.amount();
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

    fn symbol(self: *Scanner) !void {
        self.token_start = self.index - 1;
        if (self.current == '\"') {
            self.advance();
            while (!oneOf(self.current, "\r\n\"")) {
                self.advance();
            }
            self.expect('\"');    
        } else {
            while (!oneOf(self.current, "-0123456789., @;\r\n\"")) {
                self.advance();
            }
        }

        try self.tokens.append(Token{
            .token_type = TokenType.Symbol,
            .text = self.source[self.token_start..self.index-1],
            .line = self.line,
        });
    }

    fn amount(self: *Scanner) !void {
        if (self.current == '-' or self.current >= '0' and self.current <= '9') {
            // quantity, then symbol
            try self.quantity();
            while (self.current == ' ' or self.current == '\t') {
                self.advance();
            }
            try self.symbol();
        } else {
            // symbol, then quantity
            try self.symbol();
            while (self.current == ' ' or self.current == '\t') {
                self.advance();
            }
            try self.quantity();
        }
    }

    fn quantity(self: *Scanner) !void {
        self.token_start = self.index - 1;
        if (self.current == '-') self.advance();
        while (oneOf(self.current, "0123456789,")) {
            self.advance();
        }
        if (self.current == '.') {
            self.advance();
            while (oneOf(self.current, "0123456789")) {
                self.advance();
            }
        }

        try self.tokens.append(Token{
            .token_type = TokenType.Symbol,
            .text = self.source[self.token_start..self.index-1],
            .line = self.line,
        });
    }
};

// TODO: Why can't I make this a comptime "inline for"?
// Gives me error: unable to evaluate constant expression
fn oneOf(input: u8, chars: []const u8) bool {
    return for (chars) |char| {
        if (input == char) break true;
    } else false;
}
