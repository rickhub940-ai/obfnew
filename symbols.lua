-- symbols.lua
-- Random English + #@^!¢0 generator
-- ^ ห้ามติดกัน

local M = {}

local LETTERS = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
local SYMBOLS = "#@^!¢0"

local function randomChar()
    if math.random(1, 100) <= 65 then
        local i = math.random(1, #LETTERS)
        return LETTERS:sub(i, i)
    end

    local i = math.random(1, #SYMBOLS)
    return SYMBOLS:sub(i, i)
end

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

        out[#out + 1] = ch
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
