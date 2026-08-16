import fengari from "fengari";
import * as core from "fengari/src/fengaricore.js";
import * as lauxlib from "fengari/src/lauxlib.js";
import * as lualib from "fengari/src/lualib.js";

const {
  luaL_newstate,
  luaL_openlibs,
  luaL_loadstring,
  lua_pcall,
  lua_tolstring,
  lua_settop
} = {
  ...core,
  ...lauxlib,
  ...lualib
};

const {
  to_luastring,
  to_jsstring
} = core;


/*
|--------------------------------------------------------------------------
| Helpers
|--------------------------------------------------------------------------
*/

function luaError(L, prefix) {
  const value = lua_tolstring(L, -1);

  let message = "unknown Lua error";

  if (value) {
    message = to_jsstring(value);
  }

  return new Error(
    `${prefix}: ${message}`
  );
}


function runLua(L, source) {
  const status = luaL_loadstring(
    L,
    to_luastring(source)
  );

  if (status !== 0) {
    throw luaError(
      L,
      "Lua load error"
    );
  }

  const result = lua_pcall(
    L,
    0,
    0,
    0
  );

  if (result !== 0) {
    throw luaError(
      L,
      "Lua runtime error"
    );
  }
}


/*
|--------------------------------------------------------------------------
| API
|--------------------------------------------------------------------------
*/

export default async function handler(req, res) {

  if (req.method !== "POST") {
    return res.status(405).json({
      success: false,
      error: "Method Not Allowed"
    });
  }

  let L = null;

  try {

    let body = req.body;

    if (typeof body === "string") {
      body = JSON.parse(body);
    }

    const source = body?.code;

    if (typeof source !== "string") {
      return res.status(400).json({
        success: false,
        error: "Missing 'code' string"
      });
    }

    if (!source.trim()) {
      return res.status(400).json({
        success: false,
        error: "Code is empty"
      });
    }


    /*
     * Create Lua state
     */

    L = luaL_newstate();

    if (!L) {
      throw new Error(
        "Failed to create Lua state"
      );
    }

    luaL_openlibs(L);


    /*
     * Root directory
     */

    const root =
      process.cwd()
        .replace(/\\/g, "/")
        .replace(/"/g, '\\"');


    /*
     * Tell Lua where .lua files are.
     */

    runLua(
      L,
      `
        package.path =
          "${root}/?.lua;" ..
          package.path
      `
    );


    /*
     * Safely encode source
     */

    const encoded =
      JSON.stringify(source);


    /*
     * Run main.lua
     */

    const runner = `
      local VM = require("main")

      if type(VM) ~= "table" then
        error("main.lua must return a table")
      end

      if type(VM.obfuscate) ~= "function" then
        error(
          "main.lua must contain VM.obfuscate"
        )
      end

      local source = ${encoded}

      local output =
        VM.obfuscate(source)

      if type(output) ~= "string" then
        error(
          "VM.obfuscate must return string"
        )
      end

      return output
    `;


    /*
     * Load runner
     */

    const loadStatus =
      luaL_loadstring(
        L,
        to_luastring(runner)
      );

    if (loadStatus !== 0) {
      throw luaError(
        L,
        "Failed to load main"
      );
    }


    /*
     * Execute and return 1 result
     */

    const callStatus =
      lua_pcall(
        L,
        0,
        1,
        0
      );

    if (callStatus !== 0) {
      throw luaError(
        L,
        "Obfuscation failed"
      );
    }


    /*
     * Get Lua return value
     */

    const result =
      lua_tolstring(
        L,
        -1
      );

    if (!result) {
      throw new Error(
        "Obfuscator returned no output"
      );
    }

    const output =
      to_jsstring(result);


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
