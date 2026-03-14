--- Template Engine.
--
-- Supports:
--  * {# text #}       comments
--  * {= mode =}       set global escaping mode
--  * {% code %}       run Lua code
--  * {{ expr }}       print expression
--
-- Use \{ for a literal {.

local M = {}

local function trim(text)
  local from = text:match("^%s*()")
  return from > #text and "" or text:match(".*%S", from)
end

local url_encode = [==[
local function _url_encode(text, quote_plus)
  local c
  local builder = {}

  if not text then
    return ""
  end

  for i=1, #text do
    c = text:sub(i, i)
    if c == " " and quote_plus then
      builder[#builder+1] = "+"
    elseif c:find("%w") then
      builder[#builder+1] = c
    else
      for j=1, #c do
        builder[#builder+1] = ("%%%02x"):format(string.byte(c:sub(j, j)))
      end
    end
  end

  return table.concat(builder, "")
end
]==]

local html_escape_table = [==[
local _html_escape_table = {
  ["&"] = "&amp;",
  ["<"] = "&lt;",
  [">"] = "&gt;",
  ['"'] = "&quote;",
  ["'"] = "&#39;",
  ["/"] = "&#47;",
  ["\\"] = "&#92;",
}
]==]

local ESCAPE_FUNC = [==[
local _ESCAPE_FUNC = {
  raw = function(text)
    if not text then return "" end
    return text
  end,

  html = function(text)
    if not text then return "" end
    return (text:gsub("[&<>\"'/\\]", _html_escape_table))
  end,

  attribute = function(text)
    local c
    local builder = {}
    if not text then return "" end
    for i=1, #text do
      c = text:sub(i, i)
      if c:find("%w") then
        builder[#builder+1] = c
      else
        builder[#builder+1] = ("&#x%02X;"):format(utf8.codepoint(c))
      end
    end
    return table.concat(builder, "")
  end,

  js = function(text)
    local c
    local builder = {}
    if not text then return "" end
    for i=1, #text do
      c = text:sub(i, i)
      if c:find("%w") then
        builder[#builder+1] = c
      else
        builder[#builder+1] = ("\\u%04d"):format(utf8.codepoint(c))
      end
    end
    return table.concat(builder, "")
  end,

  css = function(text)
    local c
    local builder = {}
    if not text then return "" end
    for i=1, #text do
      c = text:sub(i, i)
      if c:find("%w") then
        builder[#builder+1] = c
      else
        builder[#builder+1] = ("\\%06d"):format(utf8.codepoint(c))
      end
    end
    return table.concat(builder, "")
  end,

  url = function(text)
    return _url_encode(text)
  end,

  url_plus = function(text)
    return _url_encode(text, true)
  end,

  qp = function(text)
    local c
    local cnt = 0
    local builder = {}
    if not text then return "" end
    for i=1, #text do
      c = text:sub(i, i)

      if c ~= "\t" and c ~= "\r" and c ~= "\n" and (string.byte(c) < 32 or c == "=" or string.byte(c) > 126) then
        builder[#builder+1] = "="
        builder[#builder+1] = string.format("%02X", string.byte(c))
        cnt = cnt + 3
      else
        builder[#builder+1] = c
        cnt = cnt + 1
      end

      if c == "\n" then
        cnt = 0
      end

      if cnt > 72 then
        builder[#builder+1] = "=\r\n"
        cnt = 0
      end
    end
    return table.concat(builder, "")
  end
}
]==]

local do_escape = [==[
local function _do_escape(text, escape)
  local escape_func
  if not text then
    return ""
  end
  if escape then
    escape_func = _ESCAPE_FUNC[escape]
  end
  if not escape_func then
    escape_func = _ESCAPE_FUNC[_global_escape]
  end
  if escape_func then
    return escape_func(text)
  end
  return text
end
]==]

local END_MODIFIER = {
  ["#"] = "#",
  ["="] = "=",
  ["%"] = "%",
  ["<"] = ">",
}

local MODIFIER_FUNC = {
  ["="] = function(code)
    return ("_global_escape = %q"):format(trim(code))
  end,

  ["#"] = function(_code)
    return ""
  end,

  ["%"] = function(code)
    return code
  end,

  ["<"] = function(code)
    local e
    local escape = nil

    e = code:match("%|e%([\"'].-[\"']%) *$")
    if e then
      escape = trim(e:match("[\"'](.-)[\"']"))
      code = code:sub(1, #code - #e)
    end

    if escape then
      return ("_out(_do_escape(%s, %q))"):format(code, escape)
    end
    return ("_out(_do_escape(%s, nil))"):format(code)
  end,
}

local function handle_block_ends(text)
  local modifier_set = ""
  for _, v in pairs(END_MODIFIER) do
    modifier_set = modifier_set .. "%" .. v
  end
  text = text:gsub("([" .. modifier_set .. "])} \n", "%1}\n\n")
  text = text:gsub("([" .. modifier_set .. "])}\n", "%1}")
  return text
end

local function appender(builder, text, code)
  if code then
    builder[#builder+1] = code
  elseif text and text ~= "" then
    builder[#builder+1] = ("_out(%q)"):format(text)
  end
end

local function run_block(builder, text)
  local modifier = text:sub(2, 2)
  local func = MODIFIER_FUNC[modifier]
  if func then
    appender(builder, nil, func(text:sub(3, #text - 2)))
  else
    appender(builder, text)
  end
end

local function find_unescaped(text, needle, startpos)
  local pos = startpos or 1
  while true do
    local s = text:find(needle, pos, true)
    if not s then
      return nil
    end
    if s == 1 or text:sub(s - 1, s - 1) ~= "\\" then
      return s
    end
    pos = s + 1
  end
end

function M.compile(tmpl, env)
  local builder = {
    "_ret = {}",
    "local function _out(x)",
    "  _ret[#_ret+1] = tostring(x or '')",
    "end",
  }

  local pos = 1
  local b
  local modifier
  local ret
  local func
  local err
  local out

  if tmpl == nil or #tmpl == 0 then
    return ""
  end

  tmpl = tmpl:gsub("\r\n", "\n")
  tmpl = handle_block_ends(tmpl)

  env = env or {}
  env["ipairs"]   = ipairs
  env["next"]     = next
  env["pairs"]    = pairs
  env["pcall"]    = pcall
  env["tonumber"] = tonumber
  env["tostring"] = tostring
  env["type"]     = type
  env["utf8"]     = utf8
  env["math"]     = math
  env["string"]   = string
  env["table"]    = {
    concat = table.concat,
    insert = table.insert,
    move   = table.move,
    remove = table.remove,
    sort   = table.sort,
  }
  env["os"]       = {
    clock    = os.clock,
    date     = os.date,
    difftime = os.difftime,
    time     = os.time,
  }
  env["util"] = {
  	  spairs = function (t, f)
        local a = {}
        for n in pairs(t) do table.insert(a, n) end
        table.sort(a, f)
        local i = 0      -- iterator variable
        local iter = function ()   -- iterator function
          i = i + 1
          if a[i] == nil then return nil
          else return a[i], t[a[i]]
          end
        end
        return iter
      end
  }

  builder[#builder+1] = "_global_escape = 'raw'"
  builder[#builder+1] = url_encode
  builder[#builder+1] = html_escape_table
  builder[#builder+1] = ESCAPE_FUNC
  builder[#builder+1] = do_escape

  while pos <= #tmpl do
    b = tmpl:find("<", pos, true)
    if not b then
      break
    end

    modifier = tmpl:sub(b + 1, b + 1)

    if b > 1 and tmpl:sub(b - 1, b - 1) == "\\" then
      appender(builder, tmpl:sub(pos, b - 2))
      appender(builder, "<")
      pos = b + 1

    elseif not END_MODIFIER[modifier] then
      appender(builder, tmpl:sub(pos, b))
      pos = b + 1

    else
      local end_modifier = END_MODIFIER[modifier]
      local close = end_modifier .. ">"

      appender(builder, tmpl:sub(pos, b - 1))

      local close_pos = find_unescaped(tmpl, close, b + 2)

      if close_pos then
        run_block(builder, tmpl:sub(b, close_pos + 1))
        pos = close_pos + 2
      else
        appender(builder, "<")
        pos = b + 1
      end
    end
  end

  if pos <= #tmpl then
    appender(builder, tmpl:sub(pos))
  end

  builder[#builder+1] = "return table.concat(_ret)"

  local code = table.concat(builder, "\n")

  ret, func, err = pcall(load, code, "template", "t", env)
  if not ret then
    return nil, func .. "\n\nGenerated code:\n" .. code
  end
  if not func then
    return nil, (err or "load returned nil") .. "\n\nGenerated code:\n" .. code
  end

  ret, out = pcall(func)
  if not ret then
    return nil, out .. "\n\nGenerated code:\n" .. code
  end
  return out
end

function M.compile_file(name, env)
  local f, err = io.open(name, "rb")
  if not f then
    return nil, err
  end
  local t = f:read("*all")
  f:close()
  return M.compile(t, env)
end

return M