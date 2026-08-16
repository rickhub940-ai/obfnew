-- compiler.lua
-- First custom VM bytecode compiler

local Compiler = {}
Compiler.__index = Compiler

function Compiler.new()
    return setmetatable({
        code = {},
        consts = {},
        constMap = {},
    }, Compiler)
end

function Compiler:addConst(value)
    local key = type(value) .. ":" .. tostring(value)

    if self.constMap[key] then
        return self.constMap[key]
    end

    local index = #self.consts + 1

    self.consts[index] = value
    self.constMap[key] = index

    return index
end

function Compiler:emit(op, ...)
    self.code[#self.code + 1] = {
        op,
        ...
    }
end

function Compiler:compileExpression(tokens, i)
    local token = tokens[i]

    if token.kind == "number" then
        local index = self:addConst(token.value)
        self:emit("LOADK", index)
        return i + 1

    elseif token.kind == "string" then
        local index = self:addConst(token.value)
        self:emit("LOADK", index)
        return i + 1

    elseif token.kind == "keyword" then
        if token.value == "true" then
            self:emit("LOADBOOL", true)
            return i + 1
        end

        if token.value == "false" then
            self:emit("LOADBOOL", false)
            return i + 1
        end

        if token.value == "nil" then
            self:emit("LOADNIL")
            return i + 1
        end
    end

    error("unsupported expression: " .. tostring(token.value))
end

function Compiler:compile(tokens)
    local i = 1

    while tokens[i].kind ~= "eof" do
        local token = tokens[i]

        if token.kind == "keyword" and token.value == "local" then
            local name = tokens[i + 1]

            if not name or name.kind ~= "identifier" then
                error("expected identifier after local")
            end

            i = i + 2

            if tokens[i].value ~= "=" then
                error("expected '='")
            end

            i = i + 1

            i = self:compileExpression(tokens, i)

            self:emit("SETLOCAL", name.value)

        else
            i = self:compileExpression(tokens, i)
        end

        if tokens[i] and tokens[i].value == ";" then
            i = i + 1
        end
    end

    self:emit("HALT")

    return {
        code = self.code,
        consts = self.consts,
        entryPc = 1,
        globalNames = {},
    }
end

return Compiler
