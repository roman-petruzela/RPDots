-- Official LazyVim language extras: LSP + treesitter + formatting/linting,
-- all wired up and mason-managed automatically.
return {
  { import = "lazyvim.plugins.extras.lang.python" },
  { import = "lazyvim.plugins.extras.lang.rust" },
  { import = "lazyvim.plugins.extras.lang.json" },
  { import = "lazyvim.plugins.extras.lang.typescript" },
  { import = "lazyvim.plugins.extras.lang.kotlin" },
}
