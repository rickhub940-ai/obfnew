import {
  lua,
  lauxlib,
  lualib,
  to_luastring,
  to_jsstring
} from "fengari";

function getLuaError(L, prefix) {
  const msg = lauxlib.luaL_tolstring(L, -1, null);

  return new Error(
    `${prefix}: ${to_jsstring(msg)}`
  );
}

function loadLua(L, source) {
  const status = lauxlib.luaL_loadstring(
    L,
    to_luastring(source)
  );

  if (status !== lua.LUA_OK) {
    throw getLuaError(
      L,
      "Lua load error"
    );
  }
}

function callLua(L, nargs, nresults) {
  const status = lua.lua_pcall(
    L,
    nargs,
    nresults,
    0
  );

  if (status !== lua.LUA_OK) {
    throw getLuaError(
      L,
      "Lua runtime error"
    );
  }
}

export default async function handler(req, res) {
  if (req.method !== "POST") {
    return res.status(405).json({
      success: false,
      error: "Method Not Allowed"
    });
  }

  let L;

  try {
    let body = req.body;

    if (typeof body === "string") {
      body = JSON.parse(body);
    }

    const source = body?.code;

    if (typeof source !== "string") {
      return res.status(400).json({
        success: false,
        error: "Missing code"
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

    L = lauxlib.luaL_newstate();

    if (!L) {
      throw new Error(
        "Failed to create Lua state"
      );
    }

    lualib.luaL_openlibs(L);

    /*
     * Add project root to package.path
     */

    const root =
      process.cwd()
        .replace(/\\/g, "/");

    loadLua(
      L,
      `
        package.path =
          "${root}/?.lua;" ..
          "${root}/?/init.lua;" ..
          package.path
      `
    );

    callLua(
      L,
      0,
      0
    );

    /*
     * Escape source safely
     */

    const encoded =
      JSON.stringify(source);

    /*
     * Load main.lua
     */

    const runner = `
      local Main = require("main")

      if type(Main) ~= "table" then
        error("main.lua must return a table")
      end

      if type(Main.obfuscate) ~= "function" then
        error(
          "main.lua must provide obfuscate(source)"
        )
      end

      local result =
        Main.obfuscate(${encoded})

      if type(result) ~= "string" then
        error(
          "obfuscate() must return a string"
        )
      end

      return result
    `;

    loadLua(
      L,
      runner
    );

    /*
     * Execute Lua
     */

    callLua(
      L,
      0,
      1
    );

    /*
     * Read returned string
     */

    const result =
      lauxlib.luaL_tolstring(
        L,
        -1,
        null
      );

    if (!result) {
      throw new Error(
        "Obfuscator returned no result"
      );
    }

    const output =
      to_jsstring(result);

    lua.lua_settop(
      L,
      0
    );

    return res.status(200).json({
      success: true,
      code: output
    });

  } catch (error) {

    console.error(
      "[VM-OBFUSCATOR]",
      error
    );

    return res.status(500).json({
      success: false,
      error:
        error?.message ||
        String(error)
    });
  }
}
