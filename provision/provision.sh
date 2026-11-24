#!/usr/bin/env bash
# msl 子系统初始化脚本（在 Ubuntu 里以 root 运行）
# 重跑安全：msl -c "sudo bash ~/.config/msl/provision.sh"
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

# 用法: provision.sh [GUEST_USER] [MAC_HOME]
#   GUEST_USER  子系统里要配置的账户（默认取 sudo 的调用者）
#   MAC_HOME    Mac 家目录挂进子系统后的路径（默认 /Users/<挂载的那个用户>）
GUEST_USER="${1:-${SUDO_USER:-}}"
if [ -z "$GUEST_USER" ]; then
  GUEST_USER="$(getent passwd | awk -F: '$3 >= 500 && $3 < 60000 && $7 !~ /(nologin|false)$/ {print $1; exit}')"
fi
[ -n "$GUEST_USER" ] || { echo "无法确定子系统账户，请用 sudo 运行本脚本" >&2; exit 1; }

GUEST_HOME="$(getent passwd "$GUEST_USER" | cut -d: -f6)"
GUEST_GROUP="$(id -gn "$GUEST_USER")"

MAC_HOME="${2:-}"
if [ -z "$MAC_HOME" ]; then
  if [ -d /Users ]; then
    MAC_HOME="/Users/$(ls /Users | head -1)"
  else
    MAC_HOME="/Users/$GUEST_USER"
  fi
fi
TZ_NAME="${MSL_TZ:-Asia/Kuala_Lumpur}"

# ---------- 1. 时区 / locale ----------
echo "==> 时区 / 编码"
ln -sf "/usr/share/zoneinfo/${TZ_NAME}" /etc/localtime
echo "${TZ_NAME}" > /etc/timezone
apt-get install -y --no-install-recommends locales tzdata >/dev/null
sed -i 's/^# *\(en_US.UTF-8\)/\1/; s/^# *\(zh_CN.UTF-8\)/\1/' /etc/locale.gen
locale-gen >/dev/null
update-locale LANG=en_US.UTF-8 >/dev/null

# ---------- 2. 系统更新 ----------
echo "==> 更新 apt 索引"
apt-get update -qq
echo "==> 安装基础开发工具"
apt-get install -y --no-install-recommends \
  build-essential pkg-config autoconf automake libtool cmake gdb \
  git git-lfs curl wget ca-certificates gnupg lsb-release \
  vim nano less man-db manpages tree jq unzip zip p7zip-full file rsync bc \
  tmux htop btop psmisc lsof strace procps \
  python3 python3-pip python3-venv python3-dev pipx \
  net-tools iputils-ping dnsutils iproute2 openssh-client \
  bash-completion command-not-found \
  ripgrep fd-find bat software-properties-common \
  >/dev/null
echo "==> 系统已安装包数量: $(dpkg -l | grep -c '^ii')"

# Ubuntu 里 fd/bat 的可执行文件名带后缀，补两个短名字
[ -e /usr/local/bin/fd  ] || ln -s /usr/bin/fdfind /usr/local/bin/fd
[ -e /usr/local/bin/bat ] || ln -s /usr/bin/batcat /usr/local/bin/bat

# ---------- 3. fastfetch（PPA，24.04 官方源里没有）----------
echo "==> 安装 fastfetch"
add-apt-repository -y ppa:zhangsongcui3371/fastfetch >/dev/null 2>&1 || true
apt-get update -qq
apt-get install -y fastfetch >/dev/null || echo "  !! fastfetch 安装失败（网络或 PPA 问题），可稍后重试"

# ---------- 4. 开发相关内核参数 ----------
echo "==> 调大 inotify 上限（virtiofs 下文件监听用）"
cat >/etc/sysctl.d/99-msl.conf <<'EOF'
fs.inotify.max_user_watches = 524288
fs.inotify.max_user_instances = 1024
fs.inotify.max_queued_events = 65536
EOF
sysctl -q -p /etc/sysctl.d/99-msl.conf || true

# ---------- 5. shell 环境 ----------
echo "==> 配置 shell 环境"
cat >/etc/profile.d/99-msl.sh <<'EOF'
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
EOF

# git 系统级默认（用户可在 ~/.gitconfig 覆盖）
git config --system init.defaultBranch main
git config --system --add safe.directory "${MAC_HOME}" 2>/dev/null || true

# 清理早期版本留下的旧名字
rm -f /etc/profile.d/99-wsm.sh /etc/update-motd.d/00-wsm

# ---------- 6. 登录横幅（fastfetch 优先） ----------
echo "==> 配置登录横幅"
cat >/etc/update-motd.d/00-msl <<'EOF'
#!/bin/bash
# msl 登录横幅：优先 fastfetch，没有就退回简易信息
if command -v fastfetch >/dev/null 2>&1; then
  if [ -f "$HOME/.config/fastfetch/config.jsonc" ]; then
    fastfetch --config "$HOME/.config/fastfetch/config.jsonc" 2>/dev/null && exit 0
  fi
  fastfetch 2>/dev/null && exit 0
fi

. /etc/os-release
C_G=$'\033[1;32m'; C_C=$'\033[1;36m'; C_D=$'\033[0;37m'; C_N=$'\033[0m'
printf '\n'
printf '  %sUbuntu %s%s  %s  %s\n' "$C_G" "$VERSION_ID" "$C_N" "$(uname -m)" "$(hostname)"
printf '  %s%s   内存 %s   磁盘 %s 可用%s\n' "$C_D" "$(date '+%Y-%m-%d %H:%M')" \
  "$(free -h | awk '/^Mem:/{print $2}')" "$(df -h / | awk 'NR==2{print $4}')" "$C_N"
[ -d /Users ] && printf '  %sMac 文件: __MAC_HOME__（双向可写）%s\n' "$C_C" "$C_N"
printf '\n'
EOF
sed -i "s|__MAC_HOME__|${MAC_HOME}|g" /etc/update-motd.d/00-msl
chmod +x /etc/update-motd.d/00-msl

# fastfetch 精简配置（写到用户自己的 ~/.config）
install -d -o "$GUEST_USER" -g "$GUEST_GROUP" -m 755 "$GUEST_HOME/.config/fastfetch"
cat >"$GUEST_HOME/.config/fastfetch/config.jsonc" <<'EOF'
{
  "$schema": "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json",
  "logo": {
    "type": "small",
    "source": "ubuntu",
    "padding": { "top": 1, "left": 2 }
  },
  "display": { "separator": "  " },
  "modules": [
    "title",
    "separator",
    { "type": "os" },
    { "type": "host" },
    { "type": "kernel" },
    { "type": "uptime" },
    { "type": "packages" },
    { "type": "cpu" },
    { "type": "memory" },
    { "type": "disk", "folders": "/" },
    { "type": "localip" },
    { "type": "locale" }
  ]
}
EOF
chown "$GUEST_USER:$GUEST_GROUP" "$GUEST_HOME/.config/fastfetch/config.jsonc"
chmod 644 "$GUEST_HOME/.config/fastfetch/config.jsonc"

# 关掉官方那些吵闹的横幅（含联网的 motd-news）
for f in /etc/update-motd.d/10-help-text /etc/update-motd.d/50-motd-news \
         /etc/update-motd.d/90-updates-available /etc/update-motd.d/91-contract-ua-esm-status; do
  [ -e "$f" ] && chmod -x "$f"
done
[ -e /etc/default/motd-news ] && sed -i 's/^ENABLED=1/ENABLED=0/' /etc/default/motd-news

# ---------- 7. 校验 ----------
echo "==> 校验"
printf '  sudo        : %s\n' "$(grep -rqs NOPASSWD /etc/sudoers.d/ && echo '免密' || echo '需要密码')"
printf '  Mac 家目录 : %s（%s）\n' "$MAC_HOME" "$([ -w "$MAC_HOME" ] && echo 可写 || echo '只读/不可见')"
printf '  时区       : %s\n' "$(date '+%Z %z')"
printf '  locale     : %s\n' "$(locale | head -1)"
echo "==> 初始化完成"
