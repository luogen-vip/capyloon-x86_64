# Capyloon x86_64 — 火狐 Gecko 内核操作系统 · PC 桌面移植版

将 [Capyloon](https://capyloon.org)（基于 Gecko / B2GOS 的 Web 操作系统，Firefox 的同源内核）完整移植到 **x86_64 PC**（AMD / Intel 均支持）：

- ✅ 可启动 **Live ISO**（U 盘启动，BIOS 与 UEFI 双 GRUB 引导）
- ✅ 开机 **GRUB 菜单** + **Plymouth 官方 Logo 动画**
- ✅ 进入完整 Capyloon 桌面（sway Wayland kiosk + Gecko 123 + Nutria 界面）
- ✅ **安装到本地硬盘**（GRUB 菜单直达安装器，装完拔 U 盘直接硬盘启动）
- ✅ 硬件全适配：AMD/Intel/软渲染三级显卡兜底、有线+WiFi、声音、蓝牙、U 盘、手机 MTP
- ✅ 分辨率自动适配原生命名分辨率，鼠标键盘即插即用
- ✅ 全流程 **GitHub Actions 云端自动编译**，产物自动发布到 Release

## 项目背景

Capyloon 是 B2GOS（Firefox OS 的开源延续）的现代重生，UI 全部由 Web 技术构建、由 Gecko 内核渲染。官方只面向手机设备（PinePhone Pro / Librem 5 / Pixel 3a）和桌面 Debian 软件包。本仓库把官方桌面栈完整组装成 **可启动、可安装的 PC 操作系统**。

### 技术栈

| 层 | 组件 | 说明 |
|---|---|---|
| 内核 | Debian 6.1 (bookworm) | amdgpu/radeonsi、i915、llvmpipe 软渲染三级兜底 |
| 引导 | GRUB 2 (BIOS+UEFI) + Plymouth | 官方 capyloon 主题开机动画 |
| 合成器 | sway (Wayland) | kiosk 全屏模式 |
| OS 核心 | Gecko 123 (b2g) | 从 capyloon/gecko-b2g 源码云端编译 |
| 系统服务 | api-daemon / b2ghald / ipfsd | 从源码编译（Rust） |
| 用户界面 | Nutria (System / Homescreen / 浏览器 / 终端 / 设置…) | Capyloon 官方 Web 应用 |
| 硬件层 | NetworkManager · PipeWire · BlueZ · udisks2 · libmtp | 有线/WiFi/声音/蓝牙/U盘/手机 |

## 使用方法

### 1. 下载 ISO
到 [Releases](https://github.com/luogen-vip/capyloon-x86_64/releases) 下载最新 ISO（也可以在 Actions 页面下载 CI 构建）。

### 2. 写入 U 盘（≥4GB）
Windows：Rufus（选 DD 模式）/ balenaEtcher；Linux：`dd if=capyloon-x86_64_*.iso of=/dev/sdX bs=4M oflag=direct status=progress`

### 3. 从 U 盘启动
开机按 F12/F11/ESC 选择 U 盘启动。GRUB 菜单（12 秒后自动进系统）：

| 菜单项 | 用途 |
|---|---|
| Capyloon x86_64（默认） | 直接进入系统体验 |
| 安装到硬盘 | 全自动安装：分区→复制→写 GRUB→完成 |
| 安全模式 (nomodeset) | 显卡驱动异常时使用 |
| 调试模式 | 显示完整启动日志排障 |

### 4. 安装到硬盘
选 GRUB 菜单第二项（或进系统后运行 `sudo capyloon-installer`），选择目标硬盘 → 确认 → 等待完成 → 重启拔 U 盘。安装为 GPT + ESP + BIOS 引导三重布局，**BIOS 和 UEFI 机器都能启动**。

### 默认账号
- 用户：`capyloon` / 密码：`capyloon`（sudo 免密）
- root：`root`
- tty1 (Ctrl+Alt+F1)：root 自动登录调试台；图形界面在 tty7 (Ctrl+Alt+F7)

## 从源码构建

云端（推荐）：push 到本仓库即自动触发 [.github/workflows/build.yml](.github/workflows/build.yml)，5 阶段流水线：

1. **build-gecko** (~3-4h)：`capyloon/gecko-b2g` (Gecko 123, capyloon 分支) 源码编译 x86_64 b2g
2. **build-daemons** (~15min)：api-daemon / b2ghald / ipfsd (Rust)
3. **build-deb** (~15min)：nutria jackady 打包官方格式 deb（含 x86_64 桌面 kiosk 补丁）+ 官方 plymouth 主题
4. **build-iso** (~30min)：Debian live-build 组装 BIOS+UEFI 双引导 ISO
5. **release**：自动发布 GitHub Release

本地：
```bash
bash scripts/build-gecko.sh     # 需要大磁盘 (50GB+) 与较新 CPU
bash scripts/build-daemons.sh
bash scripts/build-deb.sh
bash scripts/build-iso.sh
```

## 目录结构

```
├── .github/workflows/build.yml     # 云端编译流水线
├── scripts/
│   ├── build-gecko.sh              # Gecko(b2g) x86_64 编译
│   ├── build-daemons.sh            # Rust 守护进程编译
│   ├── build-deb.sh                # 官方格式 deb 打包
│   ├── build-iso.sh                # live-build 组装 ISO
│   └── make-grub-assets.py         # GRUB 启动背景生成
├── patches/
│   └── nutria-start-sh-desktop.patch  # 桌面 kiosk 全屏补丁 (sway)
└── iso/livebuild/                  # Debian live-build 配置
    ├── auto/config                 # lb 配置 (bookworm, BIOS+UEFI)
    ├── config/bootloaders/grub-pc/ # 定制 GRUB 菜单
    ├── config/includes.binary/     # GRUB 主题/背景
    ├── config/includes.chroot/     # 安装器/服务/系统配置
    ├── config/package-lists/       # 系统包列表 (驱动/固件全量)
    └── config/hooks/               # 系统设置钩子
```

## 硬件兼容性

| 硬件 | 状态 | 驱动/说明 |
|---|---|---|
| AMD GPU（含 A8-7500 Kaveri 等老 APU） | ✅ | radeonsi (mesa) |
| Intel GPU | ✅ | i915 (mesa) |
| 其他/异常 GPU | ✅ 兜底 | llvmpipe 软渲染（安全模式 nomodeset） |
| 有线网卡 | ✅ | 内核原生 + NetworkManager |
| WiFi | ✅ | iwlwifi/ath9k/rtl/brcm 固件全量 |
| 声音 | ✅ | ALSA + PipeWire |
| 蓝牙 | ✅ | BlueZ（`bluetoothctl` 管理） |
| U 盘 | ✅ | udisks2 自动挂载 `/media`，exFAT/NTFS 支持 |
| 手机 USB (MTP) | ✅ | libmtp + jmtpfs |
| 鼠标键盘 | ✅ | libinput |
| 时间同步 | ✅ | systemd-timesyncd（联网自动校准） |

## 故障排查

- **黑屏/花屏**：GRUB 选「安全模式 (nomodeset)」；进入后 `journalctl -u capyloon -f`
- **进不了图形界面**：Ctrl+Alt+F2 切换 tty，`cat /tmp/capyloon_gecko.log` 看 Gecko 日志
- **WiFi 连接**：图形界面 FTU 首次设置向导，或 tty 里 `nmtui`
- **重启循环**：systemd 默认 5 次/10s 起停限制，超限自动停在 tty1 调试台并显示原因

## 许可

各上游组件遵循其原始许可（Capyloon/Nutria: AGPL-3.0，Gecko: MPL-2.0，Debian: 各组件许可）。
