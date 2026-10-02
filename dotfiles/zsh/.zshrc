# ~/.zshrc do Setup Imortal.
# Tudo que é comum ao bash e ao zsh (PATH, aliases, prompt) vive em ~/.config/shell/*.sh
# e é carregado aqui. Para qualquer configuração valer nos dois shells, coloque lá.
# Dados pessoais: ~/.config/shell/99-pessoal.local.sh (o Git ignora *.local.*).

# --- Histórico ---------------------------------------------------------------
HISTFILE="$HOME/.zsh_history"
HISTSIZE=50000
SAVEHIST=50000
setopt HIST_IGNORE_DUPS HIST_IGNORE_SPACE HIST_REDUCE_BLANKS SHARE_HISTORY INC_APPEND_HISTORY

# --- Teclas e comportamento --------------------------------------------------
setopt AUTO_CD INTERACTIVE_COMMENTS NO_BEEP
bindkey -e
bindkey '^[[A' history-beginning-search-backward   # ↑ busca no histórico pelo que já foi digitado
bindkey '^[[B' history-beginning-search-forward    # ↓
bindkey '^[[H' beginning-of-line                   # Home
bindkey '^[[F' end-of-line                         # End
bindkey '^[[3~' delete-char                        # Delete

# --- Completar ---------------------------------------------------------------
autoload -Uz compinit && compinit -d "${XDG_CACHE_HOME:-$HOME/.cache}/zcompdump"
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'

# --- Configurações comuns ao bash e ao zsh -----------------------------------
for rc in "$HOME"/.config/shell/*.sh; do
  [ -r "$rc" ] && . "$rc"
done
unset rc

# --- Plugins (instalados pelo módulo "shell") --------------------------------
# Syntax-highlighting deve ser o último a carregar.
_zsh_plugins="${XDG_DATA_HOME:-$HOME/.local/share}/zsh/plugins"
[ -r "$_zsh_plugins/zsh-autosuggestions/zsh-autosuggestions.zsh" ] &&
  . "$_zsh_plugins/zsh-autosuggestions/zsh-autosuggestions.zsh"
[ -r "$_zsh_plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ] &&
  . "$_zsh_plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
unset _zsh_plugins
