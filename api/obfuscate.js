import fs from "node:fs";
import path from "node:path";

import {
  luaL_newstate,
  luaL_openlibs,
  luaL_loadstring,
  lua_pcall,
  lua_gettop,
  lua_tolstring,
  lua_settop
} from "fengari";

import {
  to_luastring,
  to_jsstring
} from "fengari/src/fengaricore.js";

const ROOT = path.join(process.cwd(), "lua");

const files = [
  "symbols.lua",
  "lexer.lua",
  "parser.lua",
  "compiler.lua",
  "optimizer.lua",
  "emit.lua",
  "main.lua"
];

function createLuaState() {
  const L = luaL_newstate();

  luaL_openlibs(L);

  for (const file of files) {
    const fullPath = path.join(ROOT, file);

    if (!fs.existsSync(fullPath)) {
      throw new Error(`Missing Lua file: ${file}`);
    }

    const source = fs.readFileSync(fullPath, "utf8");

    const status = luaL_loadstring(
      L,
      to_luastring(source)
    );

    if (status !== 0) {
      const error = lua_tolstring(L, -1);
      throw new Error(
        `Failed loading ${file}: ${
          error ? to_jsstring(error) : "unknown error"
        }`
      );
    }

    const callStatus = lua_pcall(
      L,
      0,
      0,
      0
    );

    if (callStatus !== 0) {
      const error = lua_tolstring(L, -1);
      throw new Error(
        `Failed executing ${file}: ${
          error ? to_jsstring(error) : "unknown error"
        }`
      );
    }
  }

  return L;
}

export default async function handler(req, res) {
  if (req.method !== "POST") {
    return res.status(405).json({
      success: false,
      error: "POST required"
    });
  }

  try {
    const body =
      typeof req.body === "string"
        ? JSON.parse(req.body)
        : req.body;

    const source = body?.code;

    if (typeof source !== "string") {
      return res.status(400).json({
        success: false,
        error: "Missing 'code'"
      });
    }

    if (!source.trim()) {
      return res.status(400).json({
        success: false,
        error: "Code is empty"
      });
    }

    const L = createLuaState();

    /*
     * main.lua ต้อง export function ผ่าน global
     *
     * ตัวอย่าง:
     * VM = require("main")
     * return VM.obfuscate(...)
     */

    const escaped = JSON.stringify(source);

    const runner = `
      local VM = require("main")
      local source = ${escaped}
      local result = VM.obfuscate(source)
      return result
    `;

    const status = luaL_loadstring(
      L,
      to_luastring(runner)
    );

    if (status !== 0) {
      const error = lua_tolstring(L, -1);

      throw new Error(
        error
          ? to_jsstring(error)
          : "Lua load error"
      );
    }

    const callStatus = lua_pcall(
      L,
      0,
      1,
      0
    );

    if (callStatus !== 0) {
      const error = lua_tolstring(L, -1);

      throw new Error(
        error
          ? to_jsstring(error)
          : "Lua execution error"
      );
    }

    const result = lua_tolstring(L, -1);

    const output = result
      ? to_jsstring(result)
      : "";

    lua_settop(L, 0);

    return res.status(200).json({
      success: true,
      code: output
    });

  } catch (error) {
    console.error(error);

    return res.status(500).json({
      success: false,
      error: error?.message || String(error)
    });
  }
}
