-- lexer.lua
-- Minimal Luau lexer for the first VM implementation

local Lexer = {}
Lexer.__index = Lexer

local keywords = {
    ["local"] = true,
    ["function"] = true,
    ["end"] = true,
    ["return"] = true,
    ["if"] = true,
    ["then"] = true,
    ["else"] = true,
    ["true"] = true,
    ["false"] = true,
    ["nil"] = true,
}

local function isAlpha(c)
    return c and c:match("[A-Za-z_]") ~= nil
end

local function isDigit(c)
    return c and c:match("%d") ~= nil
end

function Lexer.new(source)
    return setmetatable({
        source = source,
        pos = 1,
        len = #source,
        tokens = {},
    }, Lexer)
end

function Lexer:peek()
    return self.source:sub(self.pos, self.pos)
end

function Lexer:advance()
    local c = self.source:sub(self.pos, self.pos)
    self.pos = self.pos + 1
    return c
end

function Lexer:add(kind, value)
    self.tokens[#self.tokens + 1] = {
        kind = kind,
        value = value,
    }
end

function Lexer:skipSpace()
    while self.pos <= self.len do
        local c = self:peek()

        if c:match("%s") then
            self.pos = self.pos + 1
        elseif c == "-" and self.source:sub(self.pos, self.pos + 1) == "--" then
            while self.pos <= self.len and self:peek() ~= "\n" do
                self.pos = self.pos + 1
            end
        else
            break
        end
    end
end

function Lexer:readString()
    local quote = self:advance()
    local out = {}

    while self.pos <= self.len do
        local c = self:advance()

        if c == quote then
            return table.concat(out)
        end

        if c == "\\" then
            local n = self:advance()

            local escapes = {
                n = "\n",
                r = "\r",
                t = "\t",
                ["\\"] = "\\",
                ['"'] = '"',
                ["'"] = "'",
            }

            out[#out + 1] = escapes[n] or n
        else
            out[#out + 1] = c
        end
    end

    error("unterminated string")
end

function Lexer:readNumber()
    local start = self.pos

    while self.pos <= self.len and self:peek():match("[%d%.]") do
        self.pos = self.pos + 1
    end

    return tonumber(self.source:sub(start, self.pos - 1))
end

function Lexer:readIdentifier()
    local start = self.pos

    while self.pos <= self.len do
        local c = self:peek()

        if isAlpha(c) or isDigit(c) then
            self.pos = self.pos + 1
        else
            break
        end
    end

    local value = self.source:sub(start, self.pos - 1)

    if keywords[value] then
        return "keyword", value
    end

    return "identifier", value
end

function Lexer:run()
    while self.pos <= self.len do
        self:skipSpace()

        if self.pos > self.len then
            break
        end

        local c = self:peek()

        if c == '"' or c == "'" then
            self:add("string", self:readString())

        elseif isDigit(c) then
            self:add("number", self:readNumber())

        elseif isAlpha(c) then
            local kind, value = self:readIdentifier()
            self:add(kind, value)

        elseif c == "=" and self.source:sub(self.pos, self.pos + 1) == "==" then
            self.pos = self.pos + 2
            self:add("operator", "==")

        elseif c == "~" and self.source:sub(self.pos, self.pos + 1) == "~=" then
            self.pos = self.pos + 2
            self:add("operator", "~=")

        elseif c == "<" and self.source:sub(self.pos, self.pos + 1) == "<=" then
            self.pos = self.pos + 2
            self:add("operator", "<=")

        elseif c == ">" and self.source:sub(self.pos, self.pos + 1) == ">=" then
            self.pos = self.pos + 2
            self:add("operator", ">=")

        elseif c:match("[+%-%*/%^%%=<>]") then
            self:advance()
            self:add("operator", c)

        elseif c:match("[%(%)%,%.]") then
            self:advance()
            self:add("punctuation", c)

        elseif c == ";" then
            self:advance()
            self:add("punctuation", ";")

        else
            error("unexpected character: " .. c)
        end
    end

    self:add("eof", "<eof>")

    return self.tokens
end

return Lexer
