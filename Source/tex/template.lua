-- tex/template.lua
local M = {}

function M.compile(tpl)
  local code = {}
  local function emit(line) code[#code+1] = line .. "\n" end

  emit("return function(ctx)")
  emit("  local _ENV = setmetatable(ctx or {}, {__index=_G})")
  emit("  local _b = {}")
  emit("  local function out(s) _b[#_b+1] = tostring(s or '') end")

  local pos = 1
  local len = #tpl

  local function emit_literal(text)
    if text == "" then return end
    text = text:gsub("]]", "]]..']]..[[")
    emit("  out([[" .. text .. "]])")
  end

  while pos <= len do
    local s = tpl:find("<%%", pos)
    if not s then
      emit_literal(tpl:sub(pos))
      break
    end

    emit_literal(tpl:sub(pos, s - 1))

    local tag_start = s
    local tag_type_char = tpl:sub(tag_start + 2, tag_start + 2)
    local is_expr = (tag_type_char == "=")
    local code_start = is_expr and (tag_start + 3) or (tag_start + 2)

    local e = tpl:find("%%>", code_start)
    if not e then
      error("Unterminated <% tag at position " .. tag_start)
    end

    local raw_chunk = tpl:sub(code_start, e - 1)

    -- detect -%>
    local is_trim = false
    if tpl:sub(e-1, e-1) == "-" then
      is_trim = true
      raw_chunk = raw_chunk:gsub("%-%s*$", "")
    end

    local next_pos = e + 2

    if is_trim then
      local rest = tpl:sub(next_pos)
      local trimmed = rest:gsub("^[ \t]*\r?\n?", "")
      next_pos = next_pos + (#rest - #trimmed)
    end

    if is_expr then
      emit("  out(" .. raw_chunk .. ")")
    else
      emit("  " .. raw_chunk)
    end

    pos = next_pos
  end

  emit("  return table.concat(_b)")
  emit("end")

  local chunk, err = load(table.concat(code), "template", "t")
  if not chunk then error("Template compile error:\n" .. err) end
  return chunk()
end

function M.render(tpl, ctx)
  return M.compile(tpl)(ctx)
end

return M
