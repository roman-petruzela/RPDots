-- Use the matugen-generated colorscheme (colors/matugen.lua) by default.
-- It re-reads lua/matugen_colors.lua, which the matugen "nvim-colors" template
-- regenerates every time the wallpaper changes (see ~/.config/matugen/config.toml).
return {
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "matugen",
    },
  },
}
