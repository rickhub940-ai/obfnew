-- main.lua

local Lexer = require("lexer")
local Parser = require("parser")
local Compiler = require("compiler")
local Optimizer = require("optimizer")
local Emitter = require("emit")

local M = {}

function M.obfuscate(source)
    if type(source) ~= "string" then
        error("source must be a string")
    end

    if source == "" then
        error("source is empty")
    end

    local lexer = Lexer.new(source)
    local tokens = lexer:run()

    local parser = Parser.new(tokens)
    local ast = parser:parse()

    local compiler = Compiler.new()
    local program = compiler:compile(ast)

    program = Optimizer.optimize(program)

    return Emitter.generate(program)
end

return M
