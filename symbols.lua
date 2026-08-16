-- symbols.lua
-- Identifier-safe random names + junk symbols
-- ^ จะไม่ติดกัน

local M = {}

local LETTERS = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
local ALNUM = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
local SYMBOLS = "#@^!¢0"

local function randomFrom(str)
    local i = math.random(1, #str)
    return str:sub(i, i)
end

local function randomChar()
    if math.random(1, 100) <= 65 then
        return randomFrom(LETTERS)
    end

    return randomFrom(SYMBOLS)
end

-- ใช้สำหรับ Lua/Luau identifier
function M.identifier(minLen, maxLen)
    minLen = minLen or 8
    maxLen = maxLen or 18

    local len = math.random(minLen, maxLen)
    local out = {}

    -- ตัวแรกต้องเป็นตัวอักษร
    out[1] = randomFrom(LETTERS)

    for i = 2, len do
        out[i] = randomFrom(ALNUM)
    end

    return table.concat(out)
end

-- ใช้สำหรับ junk/data เท่านั้น
function M.generate(minLen, maxLen)
    minLen = minLen or 8
    maxLen = maxLen or 18

    local len = math.random(minLen, maxLen)
    local out = {}
    local previousCaret = false

    for i = 1, len do
        local ch

        repeat
            ch = randomChar()
        until not (ch == "^" and previousCaret)

        out[i] = ch
        previousCaret = ch == "^"
    end

    return table.concat(out)
end

function M.pool(count)
    count = count or 8

    local result = {}

    for i = 1, count do
        result[i] = M.generate()
    end

    return result
end

return M
