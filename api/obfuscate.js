import fs from "node:fs";
import path from "node:path";

import {
  luaL_newstate,
  luaL_openlibs,
  luaL_loadstring,
  lua_pcall,
  lua_tolstring,
  lua_settop
} from "fengari";

import {
  to_luastring,
  to_jsstring
} from "fengari/src/fengaricore.js";


/*
|--------------------------------------------------------------------------
| Paths
|--------------------------------------------------------------------------
*/

const ROOT = process.cwd();

const MAIN_LUA = path.join(
  ROOT,
  "main.lua"
);


/*
|--------------------------------------------------------------------------
| Lua helpers
|--------------------------------------------------------------------------
*/

function getLuaError(L, prefix) {
  const value = lua_tolstring(L, -1);

  return new Error(
    `${prefix}: ${
      value
        ? to_jsstring(value)
        : "unknown Lua error"
    }`
  );
}


function runLua(L, source, results = 0) {
  const status = luaL_loadstring(
    L,
    to_luastring(source)
  );

  if (status !== 0) {
    throw getLuaError(
      L,
      "Lua load error"
    );
  }

  const result = lua_pcall(
    L,
    0,
    results,
    0
  );

  if (result !== 0) {
    throw getLuaError(
      L,
      "Lua runtime error"
    );
  }
}


/*
|--------------------------------------------------------------------------
| Create Lua VM
|--------------------------------------------------------------------------
*/

function createLuaState() {
  const L = luaL_newstate();

  if (!L) {
    throw new Error(
      "Failed to create Lua state"
    );
  }

  luaL_openlibs(L);

  /*
   * Lua files are located directly
   * in the project root.
   *
   * Example:
   *
   * ./main.lua
   * ./lexer.lua
   * ./parser.lua
   * ./compiler.lua
   */

  const rootPath = ROOT
    .replace(/\\/g, "/")
    .replace(/"/g, '\\"');

  runLua(
    L,
    `
      package.path =
        "${rootPath}/?.lua;" ..
        package.path
    `
  );

  return L;
}


/*
|--------------------------------------------------------------------------
| Main API
|--------------------------------------------------------------------------
*/

export default async function handler(req, res) {

  /*
   * Only POST
   */

  if (req.method !== "POST") {
    return res.status(405).json({
      success: false,
      error: "Method Not Allowed. Use POST."
    });
  }


  let L = null;


  try {

    /*
     * Parse request body
     */

    let body = req.body;

    if (typeof body === "string") {
      try {
        body = JSON.parse(body);
      } catch {
        return res.status(400).json({
          success: false,
          error: "Invalid JSON."
        });
      }
    }


    /*
     * Get source code
     */

    const source = body?.code;


    if (typeof source !== "string") {
      return res.status(400).json({
        success: false,
        error: "Missing 'code' string."
      });
    }


    if (!source.trim()) {
      return res.status(400).json({
        success: false,
        error: "Code is empty."
      });
    }


    /*
     * Check main.lua
     */

    if (!fs.existsSync(MAIN_LUA)) {
      return res.status(500).json({
        success: false,
        error: "main.lua not found."
      });
    }


    /*
     * Create Lua state
     */

    L = createLuaState();


    /*
     * Safely pass source to Lua.
     *
     * We use JSON encoding so quotes,
     * newlines and backslashes are escaped.
     */

    const encodedSource =
      JSON.stringify(source);


    /*
     * Execute main.lua through require().
     *
     * main.lua should return:
     *
     * local M = {}
     *
     * function M.obfuscate(source)
     *     ...
     * end
     *
     * return M
     */

    const runner = `
      local VM = require("main")

      if type(VM) ~= "table" then
        error("main.lua must return a table")
      end

      if type(VM.obfuscate) ~= "function" then
        error(
          "main.lua must provide VM.obfuscate"
        )
      end

      local source = ${encodedSource}

      local output =
        VM.obfuscate(source)

      if type(output) ~= "string" then
        error(
          "VM.obfuscate() must return a string"
        )
      end

      return output
    `;


    /*
     * Load runner
     */

    const loadStatus = luaL_loadstring(
      L,
      to_luastring(runner)
    );


    if (loadStatus !== 0) {
      throw getLuaError(
        L,
        "Failed to load obfuscator"
      );
    }


    /*
     * Execute runner
     * and request 1 return value.
     */

    const callStatus = lua_pcall(
      L,
      0,
      1,
      0
    );


    if (callStatus !== 0) {
      throw getLuaError(
        L,
        "Obfuscation failed"
      );
    }


    /*
     * Get result
     */

    const result =
      lua_tolstring(L, -1);


    if (!result) {
      throw new Error(
        "Obfuscator returned no output"
      );
    }


    const output =
      to_jsstring(result);


    /*
     * Clear Lua stack
     */

    lua_settop(L, 0);


    /*
     * Response
     */

    return res.status(200).json({
      success: true,
      code: output
    });


  } catch (error) {

    console.error(
      "[VM-OBFUSCATOR]",
      error
    );


    if (L) {
      try {
        lua_settop(L, 0);
      } catch {}
    }


    return res.status(500).json({
      success: false,
      error:
        error?.message ||
        String(error)
    });
  }
  }
