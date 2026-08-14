-- Neovim colorscheme built from the current wallpaper via matugen.
-- lua/matugen_colors.lua is regenerated on every wallpaper change — don't
-- hand-edit it, edit ~/.config/matugen/templates/nvim-colors.lua instead.

vim.cmd("hi clear")
if vim.fn.exists("syntax_on") == 1 then
  vim.cmd("syntax reset")
end
vim.o.termguicolors = true
vim.o.background = "dark"
vim.g.colors_name = "matugen"

local ok, c = pcall(require, "matugen_colors")
if not ok then
  -- Fallback so nvim never fails to start before the first matugen run.
  c = {
    bg = "#1a120d", fg = "#f0dfd7", bg_dim = "#140d08", bg_alt = "#211712",
    bg_highlight = "#271e19", bg_float = "#2c221c", bg_popup = "#382c25",
    fg_dim = "#d7c2b8", border = "#a08d80", border_variant = "#52443a",
    primary = "#ffb68c", on_primary = "#5c2100", primary_container = "#6f3812", on_primary_container = "#ffdcc4",
    secondary = "#e5bfaa", secondary_container = "#5c4131", on_secondary_container = "#ffdbc9",
    tertiary = "#ccc992", tertiary_container = "#4a481d", on_tertiary_container = "#e9e5ab",
    error = "#ffb4ab", error_container = "#93000a", on_error_container = "#ffdad6",
    black = "#140d08", black_b = "#271e19", red = "#ffb4ab", red_b = "#ffdad6",
    green = "#ccc992", green_b = "#e9e5ab", yellow = "#e5bfaa", yellow_b = "#ffdbc9",
    blue = "#ffb68c", blue_b = "#ffdcc4", magenta = "#ccc992", magenta_b = "#e9e5ab",
    cyan = "#e5bfaa", cyan_b = "#ffdbc9", white = "#d7c2b8", white_b = "#ffdcc4",
  }
end

local function hl(group, opts)
  vim.api.nvim_set_hl(0, group, opts)
end

-- Editor UI
-- Main surfaces stay transparent (bg = "NONE") so the host terminal's own
-- background/opacity (already themed by matugen via kitty-theme.conf) shows
-- through instead of nvim painting a solid color over it. Floating windows
-- and popups (hover docs, completion, pickers) keep a solid bg so they stay
-- legible when they overlap code.
hl("Normal", { fg = c.fg, bg = "NONE" })
hl("NormalFloat", { fg = c.fg, bg = c.bg_float })
hl("NormalNC", { fg = c.fg, bg = "NONE" })
hl("FloatBorder", { fg = c.border, bg = c.bg_float })
hl("SignColumn", { bg = "NONE" })
hl("FoldColumn", { fg = c.fg_dim, bg = "NONE" })
hl("CursorLine", { bg = c.bg_highlight })
hl("CursorLineNr", { fg = c.primary, bold = true })
hl("LineNr", { fg = c.fg_dim, bg = "NONE" })
hl("Visual", { bg = c.primary_container })
hl("Search", { fg = c.on_primary_container, bg = c.primary })
hl("IncSearch", { fg = c.bg, bg = c.primary })
hl("Pmenu", { fg = c.fg, bg = c.bg_popup })
hl("PmenuSel", { fg = c.on_primary_container, bg = c.primary_container })
hl("StatusLine", { fg = c.fg, bg = "NONE" })
hl("StatusLineNC", { fg = c.fg_dim, bg = "NONE" })
hl("WinSeparator", { fg = c.border_variant, bg = "NONE" })
hl("VertSplit", { fg = c.border_variant, bg = "NONE" })
hl("TabLine", { fg = c.fg_dim, bg = "NONE" })
hl("TabLineFill", { bg = "NONE" })
hl("TabLineSel", { fg = c.primary, bold = true, bg = "NONE" })
hl("Directory", { fg = c.primary })
hl("Title", { fg = c.primary, bold = true })
hl("NonText", { fg = c.border_variant })
hl("Whitespace", { fg = c.border_variant })
hl("EndOfBuffer", { fg = "NONE", bg = "NONE" })
hl("MatchParen", { fg = c.on_primary_container, bg = c.primary_container, bold = true })

-- Syntax
hl("Comment", { fg = c.fg_dim, italic = true })
hl("Constant", { fg = c.tertiary })
hl("String", { fg = c.tertiary })
hl("Character", { fg = c.tertiary })
hl("Number", { fg = c.tertiary })
hl("Boolean", { fg = c.tertiary })
hl("Identifier", { fg = c.fg })
hl("Function", { fg = c.primary })
hl("Statement", { fg = c.secondary })
hl("Conditional", { fg = c.secondary })
hl("Repeat", { fg = c.secondary })
hl("Keyword", { fg = c.secondary, italic = true })
hl("Operator", { fg = c.fg })
hl("PreProc", { fg = c.secondary })
hl("Type", { fg = c.primary })
hl("Special", { fg = c.tertiary })
hl("Underlined", { fg = c.primary, underline = true })
hl("Error", { fg = c.error })
hl("Todo", { fg = c.on_primary_container, bg = c.primary_container, bold = true })

-- Treesitter overrides (everything else links to the syntax groups above)
hl("@variable", { fg = c.fg })
hl("@property", { fg = c.fg })
hl("@field", { fg = c.fg })
hl("@parameter", { fg = c.fg, italic = true })
hl("@constructor", { fg = c.primary })
hl("@tag", { fg = c.secondary })
hl("@tag.attribute", { fg = c.primary })
hl("@punctuation.bracket", { fg = c.fg_dim })
hl("@punctuation.delimiter", { fg = c.fg_dim })

-- LSP diagnostics
hl("DiagnosticError", { fg = c.error })
hl("DiagnosticWarn", { fg = c.secondary })
hl("DiagnosticInfo", { fg = c.primary })
hl("DiagnosticHint", { fg = c.tertiary })
hl("DiagnosticUnderlineError", { sp = c.error, undercurl = true })
hl("DiagnosticUnderlineWarn", { sp = c.secondary, undercurl = true })
hl("DiagnosticUnderlineInfo", { sp = c.primary, undercurl = true })
hl("DiagnosticUnderlineHint", { sp = c.tertiary, undercurl = true })

-- Diff / git
hl("DiffAdd", { fg = c.tertiary, bg = c.bg_alt })
hl("DiffChange", { fg = c.secondary, bg = c.bg_alt })
hl("DiffDelete", { fg = c.error, bg = c.bg_alt })
hl("DiffText", { fg = c.on_primary_container, bg = c.primary_container })
hl("GitSignsAdd", { fg = c.tertiary })
hl("GitSignsChange", { fg = c.secondary })
hl("GitSignsDelete", { fg = c.error })

-- Popular plugin groups
hl("TelescopeBorder", { fg = c.border })
hl("TelescopeSelection", { bg = c.bg_highlight })
hl("TelescopeMatching", { fg = c.primary, bold = true })
hl("WhichKey", { fg = c.primary })
hl("WhichKeyGroup", { fg = c.secondary })
hl("WhichKeyDesc", { fg = c.fg })
hl("WhichKeyBorder", { fg = c.border })
hl("NeoTreeNormal", { fg = c.fg, bg = "NONE" })
hl("NeoTreeNormalNC", { fg = c.fg, bg = "NONE" })
hl("NeoTreeDirectoryIcon", { fg = c.primary })
hl("NeoTreeGitAdded", { fg = c.tertiary })
hl("NeoTreeGitModified", { fg = c.secondary })
hl("NeoTreeGitDeleted", { fg = c.error })

-- :terminal ANSI colors, matches kitty-theme.conf
vim.g.terminal_color_0 = c.black
vim.g.terminal_color_8 = c.black_b
vim.g.terminal_color_1 = c.red
vim.g.terminal_color_9 = c.red_b
vim.g.terminal_color_2 = c.green
vim.g.terminal_color_10 = c.green_b
vim.g.terminal_color_3 = c.yellow
vim.g.terminal_color_11 = c.yellow_b
vim.g.terminal_color_4 = c.blue
vim.g.terminal_color_12 = c.blue_b
vim.g.terminal_color_5 = c.magenta
vim.g.terminal_color_13 = c.magenta_b
vim.g.terminal_color_6 = c.cyan
vim.g.terminal_color_14 = c.cyan_b
vim.g.terminal_color_7 = c.white
vim.g.terminal_color_15 = c.white_b
