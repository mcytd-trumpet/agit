#!/data/data/com.termux/files/usr/bin/bash
# install.sh - agit 一键安装器
# 用法: curl -fsSL https://bbkstore.ccwu.cc/dl/install | bash

set -e

STORE_URL="${AGIT_STORE_URL:-https://bbkstore.ccwu.cc}"
# GitHub 备用源（被墙时优先用这个）
GITHUB_RAW="${AGIT_GITHUB_RAW:-https://raw.githubusercontent.com/mcytd/agit/main/agit.sh}"
GITHUB_PROXY="${AGIT_GITHUB_PROXY:-https://ghproxy.com/}"
BIN_DIR="$HOME/.local/bin"
AGIT_PATH="$BIN_DIR/agit"
SELF="$0"

R='\033[0;31m'; G='\033[0;32m'; Y='\033[0;33m'; C='\033[0;36m'; N='\033[0m'

cleanup_self() {
  case "$SELF" in
    ""|bash|-|/bin/bash|/usr/bin/bash|/data/data/com.termux/files/usr/bin/bash) return ;;
  esac
  if [ -f "$SELF" ]; then
    rm -f "$SELF" 2>/dev/null && echo -e "${C}已删除安装脚本: $SELF${N}"
  fi
}

on_error() {
  echo
  echo -e "${R}❌ 安装失败，脚本保留: $SELF${N}"
  exit 1
}
trap on_error ERR

echo -e "${C}⚡ agit 安装器${N}"
echo "  服务器: $STORE_URL"
echo "  目标:   $AGIT_PATH"
echo

mkdir -p "$BIN_DIR"

echo "下载 agit..."
DL_OK=no

try_dl() {
  local url="$1"
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL --connect-timeout 8 --max-time 30 "$url" -o "$AGIT_PATH" 2>/dev/null && DL_OK=yes
  elif command -v wget >/dev/null 2>&1; then
    wget -q --timeout=15 -O "$AGIT_PATH" "$url" 2>/dev/null && DL_OK=yes
  fi
  [ -s "$AGIT_PATH" ] && DL_OK=yes
}

echo "  → 尝试服务器: $STORE_URL/dl/agit"
try_dl "$STORE_URL/dl/agit"
[ "$DL_OK" != "yes" ] && {
  echo "  → 服务器不可达，尝试 GitHub 代理..."
  try_dl "${GITHUB_PROXY}${GITHUB_RAW}"
}
[ "$DL_OK" != "yes" ] && {
  echo "  → 尝试 GitHub 直连..."
  try_dl "$GITHUB_RAW"
}

if [ "$DL_OK" != "yes" ]; then
  echo -e "${R}所有下载源都失败${N}"
  exit 1
fi

if [ ! -s "$AGIT_PATH" ]; then
  echo -e "${R}下载失败或文件为空${N}"
  exit 1
fi
if ! head -1 "$AGIT_PATH" | grep -q "bash"; then
  echo -e "${R}文件头异常，可能不是 agit 脚本${N}"
  echo "   内容:"; head -3 "$AGIT_PATH"
  exit 1
fi
chmod +x "$AGIT_PATH"

PATH_LINE="export PATH=\"$BIN_DIR:\$PATH\""
if ! grep -qF "$BIN_DIR" ~/.bashrc 2>/dev/null; then
  echo "$PATH_LINE" >> ~/.bashrc
  echo -e "${C}已写入 ~/.bashrc${N}"
fi
export PATH="$BIN_DIR:$PATH"

if [ ! -x "$AGIT_PATH" ]; then
  echo -e "${R}安装失败: $AGIT_PATH 不可执行${N}"
  exit 1
fi

echo
echo -e "${G}✅ agit 安装完成${N}"
echo "   位置: $AGIT_PATH"
echo

cleanup_self

echo -e "${C}下一步：运行 ${Y}agit login${C} 登录${N}"
echo "   其他: agit info | agit whoami | agit push <file.apk>"
echo
