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

local function quote(s)
    return string.format("%q", s)
end

local function encodeString(s, key)
    local out = {}

    for i = 1, #s do
        local b = string.byte(s, i)

        out[#out + 1] =
            string.char(
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

            else
                parts[#parts + 1] =
                    tostring(value)
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

    local vmName =
        "_" .. Symbols.generate(5, 10)

    local codeName =
        "_" .. Symbols.generate(5, 10)

    local constName =
        "_" .. Symbols.generate(5, 10)

    local stackName =
        "_" .. Symbols.generate(5, 10)

    local pcName =
        "_" .. Symbols.generate(5, 10)

    local opName =
        "_" .. Symbols.generate(5, 10)

    local junk = Symbols.pool(6)

    local lines = {}

    lines[#lines + 1] =
        "return function(...)"

    lines[#lines + 1] =
        "local " .. vmName .. "={}"

    lines[#lines + 1] =
        "local " .. stackName .. "={}"

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

    lines[#lines + 1] =
        "local _junk={" ..
        table.concat(
            (function()
                local t = {}

                for i, v in ipairs(junk) do
                    t[i] = quote(v)
                end

                return t
            end)(),
            ","
        ) ..
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
        "local _o=_i[1]"

    lines[#lines + 1] =
        "if _o==" .. map.LOADK .. " then " ..
        "local v=" .. constName ..
        "[_i[2]];" ..
        "if type(v)=='string' then v=_d(v) end;" ..
        stackName .. "[#" .. stackName .. "+1]=v;" ..
        pcName .. "=" .. pcName .. "+1"

    lines[#lines + 1] =
        "elseif _o==" .. map.LOADNIL .. " then " ..
        stackName .. "[#" .. stackName .. "+1]=nil;" ..
        pcName .. "=" .. pcName .. "+1"

    lines[#lines + 1] =
        "elseif _o==" .. map.LOADBOOL .. " then " ..
        stackName .. "[#" .. stackName .. "+1]=_i[2];" ..
        pcName .. "=" .. pcName .. "+1"

    lines[#lines + 1] =
        "elseif _o==" .. map.GETLOCAL .. " then " ..
        stackName .. "[#" .. stackName .. "+1]=_l[_i[2]];" ..
        pcName .. "=" .. pcName .. "+1"

    lines[#lines + 1] =
        "elseif _o==" .. map.SETLOCAL .. " then " ..
        "local v=table.remove(" .. stackName .. ");" ..
        "_l[_i[2]]=v;" ..
        pcName .. "=" .. pcName .. "+1"

    lines[#lines + 1] =
        "elseif _o==" .. map.POP .. " then " ..
        "table.remove(" .. stackName .. ");" ..
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
            "local b=table.remove(" .. stackName .. ");" ..
            "local a=table.remove(" .. stackName .. ");" ..
            stackName .. "[#" .. stackName .. "+1]=" ..
            expression .. ";" ..
            pcName .. "=" .. pcName .. "+1"
    end

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
        "[#" .. stackName .. "]"

    lines[#lines + 1] =
        "end"

    return table.concat(lines, "\n")
end

return Emitter
