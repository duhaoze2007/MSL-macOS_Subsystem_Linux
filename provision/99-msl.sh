case "${LANG:-}" in C|C.UTF-8|"") export LANG=en_US.UTF-8;; esac
# 由 msl 生成：Ubuntu 子系统的交互环境
export PATH="$HOME/.local/bin:$HOME/bin:$PATH"
export EDITOR="${EDITOR:-vim}"
export HISTSIZE=50000
export HISTFILESIZE=100000
export HISTCONTROL=ignoreboth:erasedups
shopt -s histappend checkwinsize 2>/dev/null
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias ..='cd ..'
alias ...='cd ../..'
alias df='df -h'
alias free='free -h'
alias du='du -h'
alias grep='grep --color=auto'
alias ip='ip -color=auto'

# 登录时打一次横幅（Lima 的 ssh 不带 pam_motd，所以自己来）
if [ -t 1 ] && [ -z "${MSL_BANNER:-}" ]; then
  export MSL_BANNER=1
  [ -x /etc/update-motd.d/00-msl ] && /etc/update-motd.d/00-msl
fi
