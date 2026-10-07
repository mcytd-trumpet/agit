#!/data/data/com.termux/files/usr/bin/bash
# agit - 应用商店 CLI 工具
# 用法: agit login / agit push <file|folder> / agit whoami / agit logout

VERSION="1.0"
CONFIG_DIR="$HOME/.agit"
CONFIG_FILE="$CONFIG_DIR/config"

# 颜色
R='\033[0;31m'; G='\033[0;32m'; Y='\033[0;33m'; B='\033[0;34m'; C='\033[0;36m'; N='\033[0m'

# ============ 环境检测 ============
detect_env() {
  OS="unknown"; HAS_ROOT="no"; IS_TERMUX="no"

  # root 检测：能 ls /data/data 且看到目录
  if ls -1 /data/data 2>/dev/null | head -1 | grep -q .; then
    HAS_ROOT="yes"
  fi

  # Termux 检测：能 cd 进 /data/data/com.termux
  if cd /data/data/com.termux 2>/dev/null; then
    IS_TERMUX="yes"
    OS="Android/Termux"
  fi

  # 系统类型
  UNAME=$(uname -s 2>/dev/null)
  case "$UNAME" in
    Linux*)   [ "$IS_TERMUX" = "no" ] && OS="Linux"
              ;;
    Darwin*)  OS="macOS" ;;
    MINGW*|MSYS*|CYGWIN*) OS="Windows(Git Bash)" ;;
    *)        [ "$OS" = "unknown" ] && OS="$UNAME" ;;
  esac
}

# ============ 配置 ============
save_config() {
  mkdir -p "$CONFIG_DIR"
  cat > "$CONFIG_FILE" <<EOF
STORE_URL="$STORE_URL"
DEVICE_SECRET="$DEVICE_SECRET"
USERNAME="$USERNAME"
USER_ID="$USER_ID"
EOF
  chmod 600 "$CONFIG_FILE"
}

load_config() {
  if [ -f "$CONFIG_FILE" ]; then
    . "$CONFIG_FILE"
  fi
}

# ============ Token 生成（HMAC-SHA256，用 python 算） ============
gen_token() {
  local secret="$1" uid="$2" ts="$3"
  python3 -c "
import hmac,hashlib,sys
secret='$secret'; uid='$uid'; ts='$ts'
msg=f'{uid}:{ts}'.encode()
sig=hmac.new(secret.encode(),msg,hashlib.sha256).hexdigest()[:32]
print(f'#{uid}:{ts}:{sig}#')
"
}

# ============ curl 封装 ============
api() {
  local method="$1" path="$2"; shift 2
  curl -s -X "$method" "${STORE_URL}${path}" "$@"
}

# ============ 命令：whoami ============
cmd_whoami() {
  load_config
  if [ -z "$DEVICE_SECRET" ]; then
    echo -e "${R}未登录${N}，请先运行: agit login"
    exit 1
  fi
  TOKEN=$(gen_token "$DEVICE_SECRET" "$USER_ID" "$(date +%s)")
  RES=$(api GET "/api/cli/whoami" -H "Authorization: Bearer $TOKEN")
  echo "$RES" | python3 -c "
import sys,json
d=json.load(sys.stdin)
if d.get('ok'):
    u=d['user']
    print(f'✅ 已登录: {u[\"username\"]} (id={u[\"id\"]}, role={u[\"role\"]})')
else:
    print('❌ ' + d.get('msg','失败'))
"
}

# ============ 命令：logout ============
cmd_logout() {
  rm -f "$CONFIG_FILE"
  echo "✅ 已退出登录"
}

# ============ 命令：login（设备流） ============
cmd_login() {
  load_config
  if [ -n "$DEVICE_SECRET" ]; then
    echo -e "${Y}已登录为 $USERNAME，如需切换请先 agit logout${N}"
    exit 0
  fi

  # 提示默认 URL
  DEFAULT_URL="https://bbkstore.ccwu.cc"
  printf "服务器地址 [%s]: " "$DEFAULT_URL"
  read -r INPUT_URL
  STORE_URL="${INPUT_URL:-$DEFAULT_URL}"
  STORE_URL="${STORE_URL%/}"

  echo -e "${C}正在向服务器申请设备码...${N}"
  RES=$(api POST "/api/device/request" -H "Content-Type: application/json")
  CODE=$(echo "$RES" | python3 -c "import sys,json; print(json.load(sys.stdin).get('code',''))")
  VERIFY=$(echo "$RES" | python3 -c "import sys,json; print(json.load(sys.stdin).get('verify_url',''))")

  if [ -z "$CODE" ]; then
    echo -e "${R}申请失败${N}: $RES"
    exit 1
  fi

  echo
  echo -e "${G}═══════════════════════════════════════${N}"
  echo -e "${G}  设备码:  ${Y}${CODE}${N}"
  echo -e "${G}═══════════════════════════════════════${N}"
  echo
  echo -e "${C}请打开浏览器访问:${N}"
  echo -e "  ${B}${VERIFY}${N}"
  echo
  echo -e "${Y}在页面里登录并输入上面的设备码，5 分钟内有效。${N}"
  echo

  # 尝试自动打开浏览器
  if command -v termux-open-url >/dev/null 2>&1; then
    termux-open-url "$VERIFY" 2>/dev/null &
  elif command -v xdg-open >/dev/null 2>&1; then
    xdg-open "$VERIFY" >/dev/null 2>&1 &
  fi

  # 轮询
  echo -n "等待授权"
  for i in $(seq 1 60); do
    sleep 5
    echo -n "."
    RES=$(api POST "/api/device/poll" -H "Content-Type: application/json" \
              -d "{\"code\":\"$CODE\"}")
    STATUS=$(echo "$RES" | python3 -c "import sys,json; print(json.load(sys.stdin).get('status',''))" 2>/dev/null)

    case "$STATUS" in
      verified)
        echo
        SECRET=$(echo "$RES" | python3 -c "import sys,json; print(json.load(sys.stdin).get('device_secret',''))")
        UID_VAL=$(echo "$RES" | python3 -c "import sys,json; print(json.load(sys.stdin).get('user_id',''))")
        UNAME2=$(echo "$RES" | python3 -c "import sys,json; print(json.load(sys.stdin).get('username',''))")
        DEVICE_SECRET="$SECRET"
        USER_ID="$UID_VAL"
        USERNAME="$UNAME2"
        save_config
        echo -e "${G}✅ 登录成功: ${UNAME2}${N}"
        echo -e "${C}凭证已保存到 $CONFIG_FILE${N}"
        return 0
        ;;
      expired)
        echo
        echo -e "${R}❌ 设备码已过期，请重新运行 agit login${N}"
        return 1
        ;;
    esac
  done
  echo
  echo -e "${R}❌ 超时，请重试${N}"
  return 1
}

# ============ 命令：push ============
cmd_push() {
  load_config
  if [ -z "$DEVICE_SECRET" ]; then
    echo -e "${R}未登录${N}，请先运行: agit login"
    exit 1
  fi
  if [ -z "$1" ]; then
    echo "用法: agit push <file.apk | folder>"
    exit 1
  fi

  TARGET="$1"
  if [ ! -e "$TARGET" ]; then
    echo -e "${R}路径不存在: $TARGET${N}"
    exit 1
  fi

  TOKEN=$(gen_token "$DEVICE_SECRET" "$USER_ID" "$(date +%s)")

  if [ -f "$TARGET" ]; then
    # 单文件（APK）
    if ! echo "$TARGET" | grep -qi '\.apk$'; then
      echo -e "${R}只支持 .apk 文件或文件夹${N}"
      exit 1
    fi
    FNAME=$(basename "$TARGET")
    echo -e "${C}上传 APK: $FNAME ($(du -h "$TARGET" | cut -f1))${N}"
    RES=$(curl -s -X POST "${STORE_URL}/api/cli/push" \
      -H "Authorization: Bearer $TOKEN" \
      -F "type=app" \
      -F "file=@$TARGET" \
      -F "source=agit-cli @ $(hostname 2>/dev/null || echo local)")
  elif [ -d "$TARGET" ]; then
    # 文件夹 → 打包为仓库
    FOLDER_NAME=$(basename "$(cd "$TARGET" && pwd)")
    ARCHIVE="$HOME/.agit_${FOLDER_NAME}_$(date +%s).tar.gz"
    echo -e "${C}打包文件夹: $FOLDER_NAME${N}"
    (cd "$(dirname "$TARGET")" && tar czf "$ARCHIVE" "$(basename "$TARGET")")
    SIZE=$(du -h "$ARCHIVE" | cut -f1)
    echo -e "${C}压缩包大小: $SIZE${N}"

    RES=$(curl -s -X POST "${STORE_URL}/api/cli/push" \
      -H "Authorization: Bearer $TOKEN" \
      -F "type=repo" \
      -F "name=$FOLDER_NAME" \
      -F "archive=@$ARCHIVE")

    rm -f "$ARCHIVE"
  else
    echo -e "${R}不支持的类型${N}"
    exit 1
  fi

  echo "$RES" | python3 -c "
import sys,json
d=json.load(sys.stdin)
if d.get('ok'):
    print('✅ 推送成功')
    if d.get('hash'): print('   提交:', d['hash'])
    if d.get('filename'): print('   文件:', d['filename'])
    if d.get('file'): print('   仓库:', d['file'])
else:
    print('❌ ' + d.get('msg','失败'))
    sys.exit(1)
"
}

# ============ 命令：info ============
cmd_info() {
  detect_env
  echo "agit $VERSION"
  echo "───────────────────"
  echo "  系统:    $OS"
  echo "  Root:    $HAS_ROOT"
  echo "  Termux:  $IS_TERMUX"
  echo "  配置:    $CONFIG_FILE"
  if [ -f "$CONFIG_FILE" ]; then
    . "$CONFIG_FILE"
    echo "  服务器:  $STORE_URL"
    echo "  用户:    $USERNAME"
  fi
}

# ============ 帮助 ============
show_help() {
  cat <<'HELP'
agit - 应用商店 CLI

命令:
  agit login            设备流登录
  agit logout           退出登录
  agit whoami           查看当前登录用户
  agit push <file.apk>  上传单个 APK 到应用商店
  agit push <folder>    把文件夹打包上传为仓库
  agit info             显示环境信息
  agit help             显示帮助

示例:
  agit login
  agit push 微信.apk
  agit push ./my-project
HELP
}

# ============ 入口 ============
load_config
CMD="${1:-help}"
shift 2>/dev/null || true

case "$CMD" in
  login)  cmd_login ;;
  logout) cmd_logout ;;
  whoami) cmd_whoami ;;
  push)   cmd_push "$@" ;;
  info)   cmd_info ;;
  help|-h|--help) show_help ;;
  *)
    echo "未知命令: $CMD"
    show_help
    exit 1
    ;;
esac
