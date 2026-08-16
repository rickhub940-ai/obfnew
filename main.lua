math.randomseed(
    os.time() + math.floor(os.clock() * 1000000)
)

local Lexer = require("lexer")
local Parser = require("parser")
local Compiler = require("compiler")
local Optimizer = require("optimizer")
local Emitter = require("emit")

local source = [[
local a = 10
local b = 20
a + b
]]

local lexer = Lexer.new(source)
local tokens = lexer:run()

local parser = Parser.new(tokens)
local ast = parser:parse()

local compiler = Compiler.new()
local program = compiler:compile(ast)

program = Optimizer.optimize(program)

local output = Emitter.generate(program)

print(output)
