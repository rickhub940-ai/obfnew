local Compiler = {}
Compiler.__index = Compiler

function Compiler.new()
    return setmetatable({
        code = {},
        consts = {},
        constMap = {},
        locals = {},
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

function Compiler:compileExpr(node)
    if node.type == "Number"
        or node.type == "String" then

        self:emit(
            "LOADK",
            self:addConst(node.value)
        )

    elseif node.type == "Boolean" then

        self:emit("LOADBOOL", node.value)

    elseif node.type == "Nil" then

        self:emit("LOADNIL")

    elseif node.type == "Identifier" then

        local index = self.locals[node.name]

        if not index then
            error("unknown local: " .. node.name)
        end

        self:emit("GETLOCAL", index)

    elseif node.type == "Binary" then

        self:compileExpr(node.left)
        self:compileExpr(node.right)

        local map = {
            ["+"] = "ADD",
            ["-"] = "SUB",
            ["*"] = "MUL",
            ["/"] = "DIV",
            ["%"] = "MOD",
            ["^"] = "POW",
        }

        local opcode = map[node.op]

        if not opcode then
            error("unsupported operator: " .. node.op)
        end

        self:emit(opcode)

    else
        error("unknown AST node: " .. tostring(node.type))
    end
end

function Compiler:compile(ast)
    for _, stmt in ipairs(ast.body) do

        if stmt.type == "Local" then
            local index = #self.locals + 1

            self.locals[stmt.name] = index

            self:compileExpr(stmt.value)
            self:emit("SETLOCAL", index)

        elseif stmt.type == "Expression" then
            self:compileExpr(stmt.value)
            self:emit("POP")
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
