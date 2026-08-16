local Optimizer = {}

function Optimizer.optimize(program)
    local out = {
        code = {},
        consts = program.consts,
        entryPc = program.entryPc,
        globalNames = program.globalNames,
    }

    for _, instr in ipairs(program.code) do
        if instr[1] ~= "POP" or #out.code == 0 then
            out.code[#out.code + 1] = instr
        else
            local previous = out.code[#out.code]

            if previous[1] == "LOADNIL"
                or previous[1] == "LOADBOOL"
                or previous[1] == "LOADK" then

                out.code[#out.code + 1] = instr
            else
                out.code[#out.code + 1] = instr
            end
        end
    end

    return out
end

return Optimizer
