-- Helper module to safely set highlights with hex colors, terminal colors, and highlight group links
local M = {}

local vim = vim

-- Check if a color is a hex color
local function is_hex_color(color)
  return color and color:match("^#%x%x%x%x%x%x$") ~= nil
end

-- Check if a string is an existing highlight group
local function is_highlight_group(name)
  if not name or type(name) ~= "string" then
    return false
  end
  return vim.fn.hlexists(name) == 1
end

-- Get foreground color from a highlight group as hex
local function get_hl_fg(hl_name)
  local hl = vim.api.nvim_get_hl(0, { name = hl_name, link = false })
  if hl.fg then
    return string.format("#%06x", hl.fg)
  end
  return nil
end

-- Get background color from a highlight group as hex
local function get_hl_bg(hl_name)
  local hl = vim.api.nvim_get_hl(0, { name = hl_name, link = false })
  if hl.bg then
    return string.format("#%06x", hl.bg)
  end
  return nil
end

-- Resolve color: if it's a highlight group, extract the color; otherwise return as-is
local function resolve_color(color, use_bg)
  if not color then
    return nil
  end

  -- If it's already a hex color, return it
  if is_hex_color(color) then
    return color
  end

  -- If it's a highlight group, extract the color
  if is_highlight_group(color) then
    if use_bg then
      return get_hl_bg(color) or color
    else
      return get_hl_fg(color) or color
    end
  end

  -- Otherwise it's a terminal color name
  return color
end

-- Safely set highlight - supports hex colors, terminal colors, and highlight group links
-- fg_color and bg_color can be:
--   - Hex color: "#FF0000"
--   - Terminal color name: "red", "cyan"
--   - Highlight group: "DiagnosticError" (will extract actual color)
--   - Table: { fg = "...", bg = "..." }
function M.set_highlight(group, fg_color, bg_color)
  -- Handle table format: { fg = "...", bg = "..." }
  if type(fg_color) == "table" then
    bg_color = fg_color.bg
    fg_color = fg_color.fg
  end

  if not fg_color then
    return
  end

  -- If both fg and bg are the same highlight group and we need bg, extract colors
  if bg_color and fg_color == bg_color and is_highlight_group(fg_color) then
    local resolved_fg = get_hl_fg(fg_color)
    local resolved_bg = get_hl_bg(fg_color)

    if resolved_fg and resolved_bg then
      vim.cmd("highlight " .. group .. " guifg=" .. resolved_fg .. " guibg=" .. resolved_bg)
      return
    end
  end

  -- If fg_color is a highlight group and no bg specified, link to it
  if is_highlight_group(fg_color) and not bg_color then
    vim.cmd("highlight default link " .. group .. " " .. fg_color)
    return
  end

  -- Resolve colors (extract from highlight groups if needed)
  local resolved_fg = resolve_color(fg_color, false)
  local resolved_bg = resolve_color(bg_color, true)

  -- If it's a hex color
  if is_hex_color(resolved_fg) then
    if resolved_bg and is_hex_color(resolved_bg) then
      vim.cmd("highlight " .. group .. " guifg=" .. resolved_fg .. " guibg=" .. resolved_bg)
    elseif resolved_bg then
      vim.cmd("highlight " .. group .. " guifg=" .. resolved_fg .. " guibg=" .. resolved_bg .. " ctermbg=" .. resolved_bg)
    else
      vim.cmd("highlight " .. group .. " guifg=" .. resolved_fg)
    end
  else
    -- Terminal color name: use both guifg and ctermfg
    if resolved_bg then
      vim.cmd("highlight " .. group .. " guifg=" .. resolved_fg .. " ctermfg=" .. resolved_fg .. " guibg=" .. resolved_bg .. " ctermbg=" .. resolved_bg)
    else
      vim.cmd("highlight " .. group .. " guifg=" .. resolved_fg .. " ctermfg=" .. resolved_fg)
    end
  end
end

return M
