-- emit.lua

local Symbols = require("symbols")

local Emitter = {}

local OPCODES = {
    "LOADK",
    "LOADNIL",
    "LOADBOOL",
    "GETLOCAL",
    "SETLOCAL",
    "POP",
    "DUP",

    "ADD",
    "SUB",
    "MUL",
    "DIV",
    "MOD",
    "POW",

    "HALT",
}

math.randomseed(
    os.time() + math.floor(os.clock() * 1000000)
)

local function shuffled()
    local indexes = {}

    for i = 1, #OPCODES do
        indexes[i] = i
    end

    for i = #indexes, 2, -1 do
        local j = math.random(i)

        indexes[i], indexes[j] =
            indexes[j], indexes[i]
    end

    local map = {}

    for i, name in ipairs(OPCODES) do
        map[name] = indexes[i]
    end

    return map
end

local function quote(value)
    return string.format("%q", value)
end

local function encodeString(value, key)
    local out = {}

    for i = 1, #value do
        local b = string.byte(value, i)

        out[i] = string.char(
            bit32.bxor(b, key)
        )
    end

    return quote(table.concat(out))
end

local function emitConstants(consts, key)
    local out = {}

    for i, value in ipairs(consts) do
        if type(value) == "string" then
            out[i] = encodeString(value, key)

        elseif type(value) == "number" then
            out[i] = tostring(value)

        elseif type(value) == "boolean" then
            out[i] = value and "true" or "false"

        else
            out[i] = "nil"
        end
    end

    return "{" .. table.concat(out, ",") .. "}"
end

local function emitCode(code, map)
    local out = {}

    for i, instr in ipairs(code) do
        local parts = {
            tostring(map[instr[1]])
        }

        for j = 2, #instr do
            local value = instr[j]

            if type(value) == "string" then
                parts[#parts + 1] = quote(value)

            elseif type(value) == "boolean" then
                parts[#parts + 1] =
                    value and "true" or "false"

            elseif value == nil then
                parts[#parts + 1] = "nil"

            else
                parts[#parts + 1] = tostring(value)
            end
        end

        out[i] =
            "{" .. table.concat(parts, ",") .. "}"
    end

    return "{" .. table.concat(out, ",") .. "}"
end

function Emitter.generate(program)
    local map = shuffled()
    local key = math.random(16, 240)

    -- identifier ปลอดภัย
    local vmName =
        "_" .. Symbols.identifier(5, 10)

    local codeName =
        "_" .. Symbols.identifier(5, 10)

    local constName =
        "_" .. Symbols.identifier(5, 10)

    local stackName =
        "_" .. Symbols.identifier(5, 10)

    local pcName =
        "_" .. Symbols.identifier(5, 10)

    local topName =
        "_" .. Symbols.identifier(5, 10)

    local junk = Symbols.pool(6)

    local lines = {}

    lines[#lines + 1] =
        "return function(...)"

    lines[#lines + 1] =
        "local " .. vmName .. "={}"

    lines[#lines + 1] =
        "local " .. stackName .. "={}"

    lines[#lines + 1] =
        "local " .. topName .. "=0"

    lines[#lines + 1] =
        "local " .. pcName .. "=1"

    lines[#lines + 1] =
        "local _k=" .. tostring(key)

    lines[#lines + 1] =
        "local " .. constName ..
        "=" ..
        emitConstants(program.consts, key)

    lines[#lines + 1] =
        "local " .. codeName ..
        "=" ..
        emitCode(program.code, map)

    lines[#lines + 1] =
        "local _d=function(v)local r={}for i=1,#v do r[i]=string.char(bit32.bxor(string.byte(v,i),_k))end return table.concat(r)end"

    local junkParts = {}

    for i, value in ipairs(junk) do
        junkParts[i] = quote(value)
    end

    lines[#lines + 1] =
        "local _junk={" ..
        table.concat(junkParts, ",") ..
        "}"

    lines[#lines + 1] =
        "local _c={" ..
        "LOADK=" .. map.LOADK .. "," ..
        "LOADNIL=" .. map.LOADNIL .. "," ..
        "LOADBOOL=" .. map.LOADBOOL .. "," ..
        "GETLOCAL=" .. map.GETLOCAL .. "," ..
        "SETLOCAL=" .. map.SETLOCAL .. "," ..
        "POP=" .. map.POP .. "," ..
        "DUP=" .. map.DUP .. "," ..
        "ADD=" .. map.ADD .. "," ..
        "SUB=" .. map.SUB .. "," ..
        "MUL=" .. map.MUL .. "," ..
        "DIV=" .. map.DIV .. "," ..
        "MOD=" .. map.MOD .. "," ..
        "POW=" .. map.POW .. "," ..
        "HALT=" .. map.HALT ..
        "}"

    lines[#lines + 1] =
        "local _l={}"

    lines[#lines + 1] =
        "local _r=false"

    lines[#lines + 1] =
        "while not _r do"

    lines[#lines + 1] =
        "local _i=" ..
        codeName ..
        "[" .. pcName .. "]"

    lines[#lines + 1] =
        "if not _i then error('VM program counter out of range',0) end"

    lines[#lines + 1] =
        "local _o=_i[1]"

    -- LOADK
    lines[#lines + 1] =
        "if _o==" .. map.LOADK .. " then " ..
        "local v=" .. constName .. "[_i[2]];" ..
        "if type(v)=='string' then v=_d(v) end;" ..
        topName .. "=" .. topName .. "+1;" ..
        stackName .. "[" .. topName .. "]=v;" ..
        pcName .. "=" .. pcName .. "+1"

    -- LOADNIL
    lines[#lines + 1] =
        "elseif _o==" .. map.LOADNIL .. " then " ..
        topName .. "=" .. topName .. "+1;" ..
        stackName .. "[" .. topName .. "]=nil;" ..
        pcName .. "=" .. pcName .. "+1"

    -- LOADBOOL
    lines[#lines + 1] =
        "elseif _o==" .. map.LOADBOOL .. " then " ..
        topName .. "=" .. topName .. "+1;" ..
        stackName .. "[" .. topName .. "]=_i[2];" ..
        pcName .. "=" .. pcName .. "+1"

    -- GETLOCAL
    lines[#lines + 1] =
        "elseif _o==" .. map.GETLOCAL .. " then " ..
        topName .. "=" .. topName .. "+1;" ..
        stackName .. "[" .. topName .. "]=_l[_i[2]];" ..
        pcName .. "=" .. pcName .. "+1"

    -- SETLOCAL
    lines[#lines + 1] =
        "elseif _o==" .. map.SETLOCAL .. " then " ..
        "_l[_i[2]]=" .. stackName .. "[" .. topName .. "];" ..
        stackName .. "[" .. topName .. "]=nil;" ..
        topName .. "=" .. topName .. "-1;" ..
        pcName .. "=" .. pcName .. "+1"

    -- POP
    lines[#lines + 1] =
        "elseif _o==" .. map.POP .. " then " ..
        "if " .. topName .. ">0 then " ..
        stackName .. "[" .. topName .. "]=nil;" ..
        topName .. "=" .. topName .. "-1;" ..
        "end;" ..
        pcName .. "=" .. pcName .. "+1"

    -- DUP
    lines[#lines + 1] =
        "elseif _o==" .. map.DUP .. " then " ..
        "if " .. topName .. "<1 then error('VM stack underflow',0) end;" ..
        topName .. "=" .. topName .. "+1;" ..
        stackName .. "[" .. topName .. "]=" ..
        stackName .. "[" .. topName .. "-1];" ..
        pcName .. "=" .. pcName .. "+1"

    local operations = {
        ADD = "a+b",
        SUB = "a-b",
        MUL = "a*b",
        DIV = "a/b",
        MOD = "a%b",
        POW = "a^b",
    }

    for name, expression in pairs(operations) do
        lines[#lines + 1] =
            "elseif _o==" .. map[name] .. " then " ..
            "if " .. topName .. "<2 then error('VM stack underflow',0) end;" ..
            "local b=" .. stackName .. "[" .. topName .. "];" ..
            "local a=" .. stackName .. "[" .. topName .. "-1];" ..
            stackName .. "[" .. topName .. "-1]=" .. expression .. ";" ..
            stackName .. "[" .. topName .. "]=nil;" ..
            topName .. "=" .. topName .. "-1;" ..
            pcName .. "=" .. pcName .. "+1"
    end

    -- HALT
    lines[#lines + 1] =
        "elseif _o==" .. map.HALT .. " then " ..
        "_r=true"

    lines[#lines + 1] =
        "else error('invalid VM opcode',0) end"

    lines[#lines + 1] =
        "end"

    lines[#lines + 1] =
        "return " ..
        stackName ..
        "[" .. topName .. "]"

    lines[#lines + 1] =
        "end"

    return table.concat(lines, "\n")
end

return Emitter
