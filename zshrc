# Path configuration
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$HOME/.bun/bin:$PATH"

# Oh-My-Zsh configuration
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME=""  # Using starship instead
plugins=(git fzf zoxide)
source $ZSH/oh-my-zsh.sh

# Initialize tools
eval "$(starship init zsh)"
eval "$(zoxide init zsh)"
eval "$(atuin init zsh)"

# Aliases using modern tools
alias ls='lsd'
alias ll='lsd -la'
alias lt='lsd --tree'
alias cat='bat --paging=never'

# Coding agent velocity aliases (vibe mode)
alias cc='NODE_OPTIONS="--max-old-space-size=32768" ENABLE_BACKGROUND_TASKS=1 claude --dangerously-skip-permissions'
alias cod='codex --dangerously-bypass-approvals-and-sandbox'
alias gmi='gemini --yolo'

# Agent environment
export WORKSPACE="/workspace"
export SOURCE="/source"

# Gastown environment
export GT_HOME="$WORKSPACE/gt"

# Container detection
if [ -f /.dockerenv ] || [ -f /run/.containerenv ]; then
    export CONTAINER_ENV=1
fi
