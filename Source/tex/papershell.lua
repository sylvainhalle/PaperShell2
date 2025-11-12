-- lua/papershell.lua
local template = require("tex/template_engine4")   -- vendored engine
local lfs = require("lfs")

local M = {}

local function ensure_outdir()
  if not lfs.attributes("gen","mode") then lfs.mkdir("gen") end
end

local function slurp(p)
  local f=assert(io.open(p,"r"))
  local s=f:read("*a")
  f:close()
  return s 
end
local function spit(p,s) 
  local f=assert(io.open(p,"w"))
  f:write(s)
  f:close()
end

-- parse "k=v, k2={...}" into a Lua table (recursive, brace-aware)
local function parse_kv(s)
  s = (s or ""):gsub("^%s+", ""):gsub("%s+$", "")
  local t, cur, depth = {}, "", 0

  -- Does this string contain a '=' at depth 0?
  local function has_top_level_equals(str)
    local d = 0
    for c in str:gmatch(".") do
      if c == "{" then
        d = d + 1
      elseif c == "}" then
        d = d - 1
      elseif c == "=" and d == 0 then
        return true
      end
    end
    return false
  end

  local function push()
    if cur == "" then return end
    local k, v = cur:match("^%s*([^=]+)%s*=%s*(.+)%s*$")
    cur = ""
    if not k then return end

    k = k:gsub("%s+", "")           -- strip spaces in key
    v = v:match("^%s*(.-)%s*$")     -- trim spaces around value

    -- Remove one pair of outer braces if present
    local raw = v
    if raw:match("^%b{}$") then
      raw = raw:sub(2, -2)
    end
    raw = raw:match("^%s*(.-)%s*$") -- trim again

    -- If raw looks like a nested "k=v, ..." at top level, recurse
    if has_top_level_equals(raw) then
      t[k] = parse_kv(raw)
    else
      -- simple leaf value
      if raw == "true" then
        t[k] = true
      elseif raw == "false" then
        t[k] = false
      else
        t[k] = raw
      end
    end
  end

  -- Split on commas at depth 0
  for c in s:gmatch(".") do
    if c == "{" then
      depth = depth + 1
    elseif c == "}" then
      depth = depth - 1
    end
    if c == "," and depth == 0 then
      push()
    else
      cur = cur .. c
    end
  end
  if #cur > 0 then push() end

  return t
end


function M.generate(kv_raw)
  ensure_outdir()
  local kv = parse_kv(kv_raw)
  local pub = assert((kv.publisher or ""):match("%S+"), "publisher=… is required")

  -- Render using publisher-specific templates that contain all the logic
  local pre_tpl_f = template.compile_file("tpl/"..pub.."/preamble.tpl", kv)
  spit("gen/preamble.inc.tex", pre_tpl_f)
  local mid_tpl_f = template.compile_file("tpl/"..pub.."/midamble.tpl", kv)
  spit("gen/midamble.inc.tex", pre_tpl_f)
  local pst_tpl_f = template.compile_file("tpl/"..pub.."/postamble.tpl", kv)
  spit("gen/postamble.inc.tex", pst_tpl_f)
end

return M
