#!/usr/bin/env bash
set -euo pipefail

mkdir -p "$HOME/.config/gtk-3.0" "$HOME/.config/gtk-4.0"

cat > "$HOME/.config/gtk-3.0/gtk.css" <<EOF
@define-color theme_bg_color ${background};
@define-color theme_fg_color ${foreground};
@define-color theme_base_color ${color0};
@define-color theme_selected_bg_color ${accent};
@define-color theme_selected_fg_color ${foreground};
@define-color theme_unfocused_fg_color ${color8};

window,
dialog,
popover,
.background {
  background-color: @theme_bg_color;
  color: @theme_fg_color;
}

headerbar,
.titlebar {
  background-color: @theme_base_color;
  color: @theme_fg_color;
  border-bottom: 1px solid @theme_selected_bg_color;
}

button {
  background-color: @theme_base_color;
  color: @theme_fg_color;
  border: 1px solid alpha(@theme_selected_bg_color, 0.55);
}

button:hover {
  background-color: alpha(@theme_selected_bg_color, 0.18);
}

entry,
textview,
treeview.view {
  background-color: @theme_base_color;
  color: @theme_fg_color;
}

/* Thunar-specific polish */
window.thunar paned > separator,
window.thunar sidebar,
window.thunar .sidebar,
window.thunar .standard-view,
window.thunar treeview.view {
  background-color: @theme_base_color;
  color: @theme_fg_color;
}

window.thunar treeview.view:selected,
window.thunar .standard-view:selected {
  background-color: alpha(@theme_selected_bg_color, 0.24);
  color: @theme_selected_fg_color;
}
EOF

cat > "$HOME/.config/gtk-4.0/gtk.css" <<EOF
@define-color theme_bg_color ${background};
@define-color theme_fg_color ${foreground};
@define-color theme_base_color ${color0};
@define-color theme_selected_bg_color ${accent};
@define-color theme_selected_fg_color ${foreground};
@define-color theme_unfocused_fg_color ${color8};

window,
dialog,
popover,
.background {
  background-color: @theme_bg_color;
  color: @theme_fg_color;
}

headerbar,
.titlebar {
  background-color: @theme_base_color;
  color: @theme_fg_color;
  border-bottom: 1px solid @theme_selected_bg_color;
}

button {
  background-color: @theme_base_color;
  color: @theme_fg_color;
  border: 1px solid alpha(@theme_selected_bg_color, 0.55);
}

button:hover {
  background-color: alpha(@theme_selected_bg_color, 0.18);
}

entry,
textview,
view {
  background-color: @theme_base_color;
  color: @theme_fg_color;
}

/* Thunar-specific polish */
window.thunar paned > separator,
window.thunar sidebar,
window.thunar .sidebar,
window.thunar .standard-view,
window.thunar treeview.view {
  background-color: @theme_base_color;
  color: @theme_fg_color;
}

window.thunar treeview.view:selected,
window.thunar .standard-view:selected {
  background-color: alpha(@theme_selected_bg_color, 0.24);
  color: @theme_selected_fg_color;
}
EOF
