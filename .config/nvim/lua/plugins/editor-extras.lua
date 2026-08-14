-- Fuzzy finder (files/grep/buffers/...) and a file-tree sidebar.
-- Neither ships in core LazyVim by default anymore — both are official
-- extras built on snacks.nvim, which is already a core dependency.
return {
  { import = "lazyvim.plugins.extras.editor.snacks_picker" },
  { import = "lazyvim.plugins.extras.editor.snacks_explorer" },
}
