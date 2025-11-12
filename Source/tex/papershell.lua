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

-- parse "k=v, k2={...}" into a Lua table (tolerant)
local function parse_kv(s)
  s = (s or ""):gsub("^%s+",""):gsub("%s+$","")
  local t, cur, depth = {}, "", 0
  local function push()
    local k,v = cur:match("^%s*([^=]+)%s*=%s*(.+)%s*$")
    if k then v = v:gsub("^%{",""):gsub("%}$",""); t[k:gsub("%s+","")] = v end
    cur = ""
  end
  for c in s:gmatch(".") do
    if c=="{" then depth=depth+1 elseif c=="}" then depth=depth-1 end
    if c=="," and depth==0 then push() else cur=cur..c end
  end
  if #cur>0 then push() end
  return t
end

function M.generate(kv_raw)
  ensure_outdir()
  local kv = parse_kv(kv_raw)
  local pub = assert((kv.publisher or ""):match("%S+"), "publisher=… is required")

  -- Build the context passed to templates; *no branching here*.
  local ctx = {
    title   = kv.title or "",
    authors = kv.authors or "",
    year    = kv.year or "",
    options = kv.options or "",  -- keep as string; templates decide
    publisher = pub
  }

  -- Render using publisher-specific templates that contain all the logic
  local pre_tpl_f = template.compile_file("tpl/"..pub.."/preamble.tpl", ctx)
  spit("gen/preamble.inc.tex", pre_tpl_f)
  local mid_tpl_f = template.compile_file("tpl/"..pub.."/midamble.tpl", ctx)
  spit("gen/midamble.inc.tex", pre_tpl_f)
  --local pst_tpl_f = template.compile(pst_tpl)
  --template.print(pst_tpl_f, ctx, function(s) spit("gen/postamble.inc.tex", s) end)
end

return M
