#!/usr/bin/env bash
# MSL 一键安装：装 Lima → 建 Ubuntu 实例 → 初始化 → 放好 msl 命令
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
INSTANCE="${MSL_INSTANCE:-ubuntu}"
CPUS="${MSL_CPUS:-4}"
MEM="${MSL_MEM:-8}"
DISK="${MSL_DISK:-48}"
TEMPLATE="${MSL_TEMPLATE:-template:ubuntu-24.04}"
BIN_DIR="${MSL_BIN_DIR:-$HOME/.local/bin}"

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

# 2. 虚拟机
if limactl list --format '{{.Name}}' 2>/dev/null | grep -qx "$INSTANCE"; then
  info "实例 $INSTANCE 已存在，跳过创建"
else
  info "创建 $INSTANCE（$CPUS 核 / ${MEM}GiB 内存 / ${DISK}GiB 磁盘上限）"
  limactl create --name="$INSTANCE" \
    --cpus="$CPUS" --memory="$MEM" --disk="$DISK" \
    --mount-writable --containerd=none --rosetta --tty=false \
    "$TEMPLATE"
fi

info "启动 $INSTANCE（首次约 30 秒）"
limactl start --tty=false "$INSTANCE" >/dev/null

# 3. 子系统初始化
info "初始化子系统：apt 更新、开发工具链、fastfetch、locale/时区"
limactl shell "$INSTANCE" -- sudo bash -s < "$REPO_DIR/provision/provision.sh"

# 4. 命令
info "安装命令到 $BIN_DIR"
mkdir -p "$BIN_DIR"
install -m 755 "$REPO_DIR/msl" "$BIN_DIR/msl"
ln -sf msl "$BIN_DIR/wsm"
ln -sf msl "$BIN_DIR/ubuntu"

case ":$PATH:" in
  *":$BIN_DIR:"*) ;;
  *) warn "$BIN_DIR 不在 PATH 里，把它加进去，或新开一个终端" ;;
esac

info "完成。试试： msl"
