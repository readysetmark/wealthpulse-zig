const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

// Public 

// Scan source string for tokens
// TODO: Set up some unit tests for good and bad Price strings!
// TODO: Need a return type! (see section 4.1)
// TODO: Parsing price file vs ledger file!
pub fn scanTokens(allocator: Allocator, source: []const u8) !void {
    // TODO: Allocating here, need to deallocate somewhere!
    var priceScanner = Scanner{
        .source = source,
        .tokens = ArrayList(Token).init(allocator),
    };
    try priceScanner.scanTokens();
}


// Private

const PriceSentinelCharacter = 'P';

// Types of tokens we may find in the files we parse
// TODO: When parsing ledger vs price file, consider whether it makes sense to make those distinct enums?
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

// For keeping track of information about a token
const Token = struct {
    token_type: TokenType,
    text: ?[]const u8,
    line: usize,

    // TODO: Make a "constructor"? Not sure if that's a thing in Zig though

    fn printDebug(self: *const Token) void {
        // TODO: can I use std.fmt.format to produce a string instead?
        // ... or std.io.Writer interface to print to any writer? (need to understand Zig interfaces)
        if (self.text == null) {
            std.log.debug("Token: (Line {}) {}", .{self.line, self.token_type});
        } else {
            std.log.debug("Token: (Line {}) {} '{s}'", .{self.line, self.token_type, self.text});
        }
    }
};

// THINKING: Would like the scanner to be less "stateful"
// I kind of liked the engine from the go version, but I didn't like how the individual parser
// pieces needed to know what's next, since it made them less flexible... as in harder to reuse
// in a different context (e.g. date as part of a price entry vs date as part of a journal entry)

// Since the price file is the simplest to parse, now's the time to figure out the pattern
// [ ] parse the real price file
// [ ] experiment with different versions of the scanner
// [ ] get error handling right!

// The scanner engine
const Scanner = struct {
    source: []const u8,
    tokens: ArrayList(Token),
    current: u8 = undefined,
    token_start: usize = 0,
    index: usize = 0,
    line: usize = 1,

    // Works its way through the source file, adding tokens until it runs out of characters
    fn scanTokens(self: *Scanner) !void {
        // TODO: Need better error handling (see section 4.1.1)
        // TODO: Probably don't want to log self.source when I start testing with real files..!
        std.log.debug("Parsing text (length {}): {s}", .{self.source.len, self.source});

        while (self.index < self.source.len) {
            // I think I've deviated from "Crafting Interpreters" here because I'm not parsing a programming language,
            // but instead a data file format... so as soon as I identify a token that starts a section, I may as well
            // expect to parse the rest of the section...
            // I guess I'm not sure yet if this is good idea or a naive one.
            // I think I'd have to have a lot more tokens if I followed the book more closely?
            // But maybe it'll make error messages harder?

            // Start of new token
            self.token_start = self.index;

            self.advance();
            
            if (self.current == PriceSentinelCharacter) {
                try self.price();
            } else if (self.current == '\r') {
                // do nothing
            } else if (self.current == '\n') {
                self.line += 1;
            } else {
                std.log.err("(Line {}) Expecting '{c}' but found: {}", .{self.line, PriceSentinelCharacter, self.current});
            }

            // TEMPORARY: Jump to the end to short-circuit parsing the rest!
            //self.index = self.source.len;
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

    // Helpers

    // read the next token into `current` and advance `index`
    // if reached the end of source, will set `current` to 0
    fn advance(self: *Scanner) void {
        if (self.index >= self.source.len)
        {
            // reached the end of the source
            self.current = 0;
            self.index = self.source.len + 1;
        } else {
            self.current = self.source[self.index];
            self.index += 1;
        }
    }

    // test current character, and advance if a match
    fn expect(self: *Scanner, character: u8) void {
        if (self.current == character) {
            self.advance();
        } else {
            std.log.err("(Line {}) Expecting '{c}' but found: {c}", .{self.line, character, self.current});
        }
    }

    // Token Parsers

    // Parse a price entry (date, symbol, price), emitting tokens as we go
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

    // Parse date in yyyy-MM-dd format
    // For now, emit a token for each component (year, month, day)
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
            .token_type = TokenType.Quantity,
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
