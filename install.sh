#!/usr/bin/env bash
# MSL 一键安装：装 Lima、放好 msl 命令，然后直接进入首次设置（输入用户名和密码）
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
BIN_DIR="${MSL_BIN_DIR:-$HOME/.local/bin}"
CONF_DIR="$HOME/.config/msl"

info() { printf '\033[36m>>\033[0m %s\n' "$*"; }
warn() { printf '\033[33m!!\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[31m!!\033[0m %s\n' "$*" >&2; exit 1; }

[ "$(uname -s)" = "Darwin" ] || die "只支持 macOS"
[ "$(uname -m)" = "arm64" ] || warn "当前不是 Apple Silicon，能跑但性能会明显下降"
command -v brew >/dev/null 2>&1 || die "需要 Homebrew：https://brew.sh"

# 1. Lima
if command -v limactl >/dev/null 2>&1; then
  info "limactl 已安装：$(limactl --version 2>/dev/null | head -1)"
else
  info "安装 lima（brew）"
  brew install lima
fi

# 2. 命令与初始化脚本
info "安装 msl 到 $BIN_DIR"
mkdir -p "$BIN_DIR" "$CONF_DIR"
install -m 755 "$REPO_DIR/msl" "$BIN_DIR/msl"
ln -sf msl "$BIN_DIR/wsm"
ln -sf msl "$BIN_DIR/ubuntu"

install -m 644 "$REPO_DIR/provision/provision.sh" "$CONF_DIR/provision.sh"
install -m 644 "$REPO_DIR/provision/99-msl.sh"   "$CONF_DIR/99-msl.sh"
install -m 644 "$REPO_DIR/provision/00-msl"      "$CONF_DIR/00-msl"
install -m 644 "$REPO_DIR/provision/fastfetch.jsonc" "$CONF_DIR/fastfetch.jsonc"

case ":$PATH:" in
  *":$BIN_DIR:"*) ;;
  *) warn "$BIN_DIR 不在 PATH 里，装完把它加进去" ;;
esac

# 3. 首次设置：没建过实例就进向导，建过就直接进 shell
info "接下来会创建子系统账户（像 Windows 上第一次启动 Ubuntu 一样）"
exec "$BIN_DIR/msl"
