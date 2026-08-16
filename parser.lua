local Parser = {}
Parser.__index = Parser

function Parser.new(tokens)
    return setmetatable({
        tokens = tokens,
        pos = 1,
    }, Parser)
end

function Parser:current()
    return self.tokens[self.pos]
end

function Parser:advance()
    local t = self.tokens[self.pos]
    self.pos = self.pos + 1
    return t
end

function Parser:expect(value)
    local t = self:current()

    if not t or t.value ~= value then
        error("expected '" .. value .. "'")
    end

    return self:advance()
end

function Parser:parsePrimary()
    local t = self:advance()

    if t.kind == "number" then
        return {
            type = "Number",
            value = t.value,
        }
    end

    if t.kind == "string" then
        return {
            type = "String",
            value = t.value,
        }
    end

    if t.kind == "identifier" then
        return {
            type = "Identifier",
            name = t.value,
        }
    end

    if t.kind == "keyword" then
        if t.value == "true" or t.value == "false" then
            return {
                type = "Boolean",
                value = t.value == "true",
            }
        end

        if t.value == "nil" then
            return {
                type = "Nil",
            }
        end
    end

    if t.value == "(" then
        local expr = self:parseExpression()
        self:expect(")")
        return expr
    end

    error("unexpected token: " .. tostring(t.value))
end

local precedence = {
    ["+"] = 10,
    ["-"] = 10,
    ["*"] = 20,
    ["/"] = 20,
    ["%"] = 20,
    ["^"] = 30,
}

function Parser:parseExpression(minPrec)
    minPrec = minPrec or 0

    local left = self:parsePrimary()

    while true do
        local t = self:current()
        local prec = t and precedence[t.value]

        if not prec or prec < minPrec then
            break
        end

        local op = self:advance().value
        local right = self:parseExpression(prec + 1)

        left = {
            type = "Binary",
            op = op,
            left = left,
            right = right,
        }
    end

    return left
end

function Parser:parseStatement()
    local t = self:current()

    if t.kind == "keyword" and t.value == "local" then
        self:advance()

        local name = self:advance()

        if name.kind ~= "identifier" then
            error("expected identifier")
        end

        self:expect("=")

        return {
            type = "Local",
            name = name.value,
            value = self:parseExpression(),
        }
    end

    return {
        type = "Expression",
        value = self:parseExpression(),
    }
end

function Parser:parse()
    local body = {}

    while self:current().kind ~= "eof" do
        body[#body + 1] = self:parseStatement()

        if self:current().value == ";" then
            self:advance()
        end
    end

    return {
        type = "Chunk",
        body = body,
    }
end

return Parser
