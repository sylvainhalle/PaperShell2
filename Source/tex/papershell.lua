-- lua/papershell.lua
local template = require 'tex/template'
local lfs = require 'lfs'

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

-- =========================================
-- LaTeX key=value parser for papershellsetup
-- Supports nested maps and arrays
--
-- Example LaTeX:
-- \papershellsetup{
--   publisher = {ieeetran},
--   title     = {My Paper},
--   authors   = {
--     { name={Marty McFly},  institution={1}, email={marty@hvhs.edu} },
--     { name={Emmett Brown}, institution={2}, email={eb@ti.com} }
--   },
--   institutions = {
--     { name={Hill Valley High School}, country={Hill Valley, CA} },
--     { name={Temporal Industries},      country={Hill Valley, CA} }
--   },
--   year      = {2025},
--   options   = {
--      twocolumn = true,
--      times     = true,
--      natbib    = true
--   }
-- }
--
-- Result in Lua (sketch):
-- cfg = parse_kv(...)
-- cfg.authors[1].name            --> "Marty McFly"
-- cfg.authors[1].institution     --> 1
-- cfg.institutions[1].name       --> "Hill Valley High School"
-- cfg.options.twocolumn          --> true
-- cfg.year                       --> 2025
-- =========================================

-- -------- Helpers --------

local function trim(s)
  return (s or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

-- Split on commas that are *not* inside braces
local function split_top_level(s)
  local parts, cur, depth = {}, "", 0
  for c in s:gmatch(".") do
    if c == "{" then
      depth = depth + 1
    elseif c == "}" then
      depth = depth - 1
    end
    if c == "," and depth == 0 then
      local piece = trim(cur)
      if piece ~= "" then table.insert(parts, piece) end
      cur = ""
    else
      cur = cur .. c
    end
  end
  local piece = trim(cur)
  if piece ~= "" then table.insert(parts, piece) end
  return parts
end

-- Does this string contain an '=' at depth 0?
local function has_top_level_equals(s)
  local depth = 0
  for c in s:gmatch(".") do
    if c == "{" then
      depth = depth + 1
    elseif c == "}" then
      depth = depth - 1
    elseif c == "=" and depth == 0 then
      return true
    end
  end
  return false
end

-- Parse a scalar (no outer braces)
local function parse_scalar(raw)
  raw = trim(raw)
  if raw == "" then return "" end

  if raw == "true" then return true end
  if raw == "false" then return false end

  -- integer; extend here if you want floats too
  if raw:match("^[+-]?%d+$") then
    local n = tonumber(raw)
    if n ~= nil then return n end
  end

  return raw
end

-- Forward declaration
local parse_value

-- -------- Recursive value parser --------

parse_value = function(str)
  str = trim(str or "")
  if str == "" then return "" end

  -- Braced thing: could be scalar, map, or array
  if str:match("^%b{}$") then
    local inner = trim(str:sub(2, -2) or "")
    if inner == "" then
      return {} -- treat {} as empty table
    end

    local parts = split_top_level(inner)

    -- Single braced scalar: {Marty McFly}
    if #parts == 1 and not has_top_level_equals(inner) then
      return parse_scalar(inner)
    end

    -- Decide map vs array
    local any_eq, all_eq = false, true
    for _, part in ipairs(parts) do
      local he = has_top_level_equals(part)
      if he then any_eq = true else all_eq = false end
    end

    if all_eq and any_eq then
      -- Map: { key = val, key2 = val2 }
      local t = {}
      for _, part in ipairs(parts) do
        local k, v = part:match("^%s*([^=]+)%s*=%s*(.+)%s*$")
        if k and v then
          k = k:gsub("%s+", "") -- strip spaces in key name
          t[k] = parse_value(v)
        end
      end
      return t
    else
      -- Array: { {...}, {...} } or { 1, 2, 3 }
      local arr = {}
      for _, part in ipairs(parts) do
        arr[#arr + 1] = parse_value(part)
      end
      return arr
    end
  end

  -- Not braced at all: plain scalar
  return parse_scalar(str)
end

-- -------- Top-level "k=v, k2=..." parser --------

-- This is the function you call from your LuaLaTeX code.
-- Example: local cfg = parse_kv(arg_string_from_TeX)
function parse_kv(s)
  s = trim(s or "")
  local t, cur, depth = {}, "", 0

  local function push()
    local chunk = trim(cur)
    cur = ""
    if chunk == "" then return end

    local k, v = chunk:match("^([^=]+)%s*=%s*(.+)$")
    if not k or not v then return end

    k = k:gsub("%s+", "") -- normalize key (remove spaces)
    t[k] = parse_value(v)
  end

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
  
  -- Read templates
  local pre_tpl = slurp("tpl/" .. pub .. "/preamble.tpl")
  local mid_tpl = slurp("tpl/" .. pub .. "/midamble.tpl")
  local pst_tpl = slurp("tpl/" .. pub .. "/postamble.tpl")

  -- Compile them
  local pre_fn = template.compile(pre_tpl)
  local mid_fn = template.compile(mid_tpl)
  local pst_fn = template.compile(pst_tpl)

  -- Run them with context
  local pre_out = pre_fn(kv)
  local mid_out = mid_fn(kv)
  local pst_out = pst_fn(kv)

  -- Write results
  spit("gen/preamble.inc.tex",  pre_out)
  spit("gen/midamble.inc.tex",  mid_out)
  spit("gen/postamble.inc.tex", pst_out)
end

return M
