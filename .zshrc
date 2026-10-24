if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

export ZSH=/usr/share/oh-my-zsh
[[ -d $ZSH ]] || ZSH="$HOME/.oh-my-zsh"
ZSH_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/oh-my-zsh"
[[ -d $ZSH_CACHE_DIR/completions ]] || mkdir -p "$ZSH_CACHE_DIR/completions"

ZSH_THEME=""

plugins=(
git
fzf
docker
python
rust
sudo
archlinux
)

[[ -f $ZSH/oh-my-zsh.sh ]] && source $ZSH/oh-my-zsh.sh

for p in zsh-autosuggestions zsh-syntax-highlighting; do
  [[ -f /usr/share/zsh/plugins/$p/$p.zsh ]] && source /usr/share/zsh/plugins/$p/$p.zsh
done
unset p

if [[ -n $SSH_CONNECTION ]]; then
  export EDITOR='vim'
else
  (( $+commands[nvim] )) && export EDITOR='nvim' || export EDITOR='vim'
fi

(( $+commands[eza] )) && alias ls="eza --icons --group-directories-first"
(( $+commands[fastfetch] )) && alias fetch="fastfetch"

typeset -g POWERLEVEL9K_MODE=nerdfont-complete
typeset -g POWERLEVEL9K_INSTANT_PROMPT=quiet
typeset -g POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=(os_icon dir vcs newline prompt_char)
typeset -g POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS=(status command_execution_time background_jobs time)
typeset -g POWERLEVEL9K_COMMAND_EXECUTION_TIME_THRESHOLD=3
typeset -g POWERLEVEL9K_PROMPT_CHAR_OK_VIINS_CONTENT_EXPANSION='❯'
typeset -g POWERLEVEL9K_PROMPT_CHAR_ERROR_VIINS_CONTENT_EXPANSION='❯'

[[ -f "${XDG_CACHE_HOME:-$HOME/.cache}/niri-rice/p10k-colors.zsh" ]] \
  && source "${XDG_CACHE_HOME:-$HOME/.cache}/niri-rice/p10k-colors.zsh"

[[ -f /usr/share/zsh-theme-powerlevel10k/powerlevel10k.zsh-theme ]] \
  && source /usr/share/zsh-theme-powerlevel10k/powerlevel10k.zsh-theme

[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

export PATH=$PATH:$HOME/.spicetify

(( $+commands[fnm] ))    && eval "$(fnm env --use-on-cd)"
(( $+commands[zoxide] )) && eval "$(zoxide init zsh)"
(( $+commands[atuin] ))  && eval "$(atuin init zsh)"
export PATH="$HOME/.local/bin:$PATH"

bindkey '^[[1;6D' backward-word
bindkey '^[[1;6C' forward-word
bindkey '^[[1;2D' backward-char
bindkey '^[[1;2C' forward-char

autoload -Uz add-zsh-hook
__rice_sync_cli_theme_env() {
  local env_file="${XDG_CACHE_HOME:-$HOME/.cache}/niri-rice/theme-env.sh"
  [[ -r "$env_file" ]] && source "$env_file"
}
add-zsh-hook precmd __rice_sync_cli_theme_env
add-zsh-hook preexec __rice_sync_cli_theme_env

export SDKMAN_DIR="$HOME/.sdkman"
[[ -s "$SDKMAN_DIR/bin/sdkman-init.sh" ]] && source "$SDKMAN_DIR/bin/sdkman-init.sh"
