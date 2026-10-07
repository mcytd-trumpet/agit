# agit

> 应用商店命令行工具 —— 用 `git` 一样的手感，把 APK 或整个文件夹推到应用商店。

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

---

## 简介

`agit` 是一个轻量的命令行工具，配合兼容的**应用商店服务端**使用，支持：

- 📱 上传单个 APK 到商店（自动提取图标、分类、来源信息）
- 📦 把整个文件夹打包为"仓库"上传（类似 git 的推送）
- 🔐 设备流登录（浏览器授权，无需在终端输入密码）
- 🖥️ 自动检测运行环境（Android/Termux、Linux、macOS）

## 快速开始

### 一键安装

```bash
curl -fsSL https://ghproxy.com/https://raw.githubusercontent.com/mcytd-trumpet/agit/main/install.sh | bash

### 手动安装

```bash
mkdir -p ~/.local/bin
curl -fsSL https://ghproxy.com/https://raw.githubusercontent.com/mcytd-trumpet/agit/main/agit.sh -o ~/.local/bin/agit
chmod +x ~/.local/bin/agit
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

登录

```bash
agit login
```

终端会显示 8 位设备码：

```
═══════════════════════════════════════
  设备码:  H3DYJUV8
═══════════════════════════════════════
```

在浏览器中登录并输入设备码即可完成授权。凭证保存在 ~/.agit/config（chmod 600）。

推送

```bash
# 上传单个 APK
agit push 微信.apk

# 上传整个文件夹（自动打包为 tar.gz 仓库）
agit push ./my-project

# 查看当前用户
agit whoami

# 环境检测
agit info

# 退出登录
agit logout
```


## 命令一览

| 命令 | 说明 |
|------|------|
| `agit login` | 设备流登录 |
| `agit logout` | 退出登录 |
| `agit whoami` | 查看当前登录用户 |
| `agit push <file.apk>` | 上传单个 APK |
| `agit push <folder>` | 打包文件夹作为仓库上传 |
| `agit info` | 显示环境信息（系统 / Root / Termux） |
| `agit help` | 显示帮助 |

## 环境支持

| 环境 | 支持 | 说明 |
|------|------|------|
| Android / Termux | ✅ | 原生支持，会自动检测 |
| Linux | ✅ | 需安装 `curl` 或 `wget`、`python3` |
| macOS | ✅ | 同上 |
| Windows (Git Bash / WSL) | ⚠️ | 未充分测试 |

## 依赖

- `bash` 4.0+
- `curl` 或 `wget`
- `python3`（用于签名和 JSON 解析）
- `tar`（推送文件夹时用到）

## 配置文件

登录凭证保存在 `~/.agit/config`，格式：

```

STORE_URL="https://your-store.example.com"
DEVICE_SECRET="..."
USERNAME="your-name"
USER_ID=1

```

**请妥善保管此文件**，它等价于你的 API 密钥。

## 服务端要求

`agit` 需要一个兼容的应用商店服务端，实现以下接口：

- `POST /api/device/request` — 申请设备码
- `POST /api/device/poll` — 轮询授权结果
- `POST /api/device/verify` — 浏览器端授权
- `GET  /api/cli/whoami` — 校验 token
- `POST /api/cli/push` — 上传应用 / 仓库

服务端使用 **HMAC-SHA256** 时间窗口校验 token，`device_secret` 由服务端生成并下发一次。

## 环境变量

| 变量 | 说明 |
|------|------|
| `AGIT_STORE_URL` | 覆盖默认服务器地址 |

## 安全说明

- ✅ 密码永不在终端输入（全程浏览器）
- ✅ Token 使用 HMAC-SHA256 签名，每次请求都不同
- ✅ `device_secret` 保存在本地 `chmod 600` 文件中
- ✅ 设备码 5 分钟过期，一次性使用
- ⚠️ 切勿将 `~/.agit/config` 分享给他人

## License

[MIT](LICENSE)
