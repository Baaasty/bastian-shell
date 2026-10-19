# ERZEUGT aus theme/palette.json (hearth) – nicht von Hand ändern. Neu erzeugen: python3 -I theme/gen/zsh.py

# --- Syntax-Highlighting (vor dem Laden des Plugins gesetzt) ---
typeset -gA ZSH_HIGHLIGHT_STYLES
ZSH_HIGHLIGHT_STYLES[default]='fg=#F6ECDD'
ZSH_HIGHLIGHT_STYLES[command]='fg=#F6ECDD,bold'
ZSH_HIGHLIGHT_STYLES[builtin]='fg=#F6ECDD,bold'
ZSH_HIGHLIGHT_STYLES[alias]='fg=#F6ECDD,bold'
ZSH_HIGHLIGHT_STYLES[function]='fg=#F6ECDD,bold'
ZSH_HIGHLIGHT_STYLES[precommand]='fg=#F2A58A,italic'
ZSH_HIGHLIGHT_STYLES[reserved-word]='fg=#F2A58A'
ZSH_HIGHLIGHT_STYLES[unknown-token]='fg=#E0604F'
ZSH_HIGHLIGHT_STYLES[path]='fg=#F6ECDD,underline'
ZSH_HIGHLIGHT_STYLES[path_prefix]='fg=#D2C2AE,underline'
ZSH_HIGHLIGHT_STYLES[globbing]='fg=#F2A58A'
ZSH_HIGHLIGHT_STYLES[single-hyphen-option]='fg=#A07C5C'
ZSH_HIGHLIGHT_STYLES[double-hyphen-option]='fg=#A07C5C'
ZSH_HIGHLIGHT_STYLES[single-quoted-argument]='fg=#E0AE55'
ZSH_HIGHLIGHT_STYLES[double-quoted-argument]='fg=#E0AE55'
ZSH_HIGHLIGHT_STYLES[dollar-quoted-argument]='fg=#E0AE55'
ZSH_HIGHLIGHT_STYLES[back-quoted-argument]='fg=#F2A58A'
ZSH_HIGHLIGHT_STYLES[dollar-double-quoted-argument]='fg=#F2A58A'
ZSH_HIGHLIGHT_STYLES[commandseparator]='fg=#B5A591'
ZSH_HIGHLIGHT_STYLES[redirection]='fg=#B5A591'
ZSH_HIGHLIGHT_STYLES[comment]='fg=#B5A591,italic'
ZSH_HIGHLIGHT_STYLES[arg0]='fg=#F6ECDD'

# --- Autosuggestion: leise, aber lesbar ---
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=#B5A591'

# --- fzf ---
export DESKTOP_FZF_COLORS='fg:#D2C2AE,bg:-1,hl:#F2A58A,fg+:#F6ECDD,bg+:#5C392D,hl+:#F2A58A,info:#B5A591,prompt:#DB6B4C,pointer:#DB6B4C,marker:#A3B083,spinner:#DB6B4C,header:#B5A591,border:#553C2E,gutter:-1,query:#F6ECDD,separator:#463226,scrollbar:#6B4A38,label:#D2C2AE'

# --- Completion-Menü: Auswahl als ruhige Akzentfläche ---
DESKTOP_MENU_SELECT='#5C392D'
DESKTOP_DESC_COLOR='#B5A591'
DESKTOP_GROUP_COLOR='#F2A58A'

# --- bat: eigenes Farbschema aus der Palette (theme/gen/bat.py) ---
export BAT_THEME=desktop
