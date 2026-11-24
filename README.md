# MSL — macOS Subsystem for Linux

**MSL is WSL for macOS.** One command gets you in and out of an ARM-native Ubuntu VM: your Mac
files appear at the same path inside the guest (read-write), and anything listening inside the
VM is forwarded to `localhost` automatically.

The name mirrors WSL = **W**indows **S**ubsystem for **L**inux, so on a Mac it is
**M**acOS **S**ubsystem for **L**inux.

[English](#english) · [中文](#中文)

```
                                you@lima-ubuntu
         ..;,; .,;,.        -------------------
      .,lool: .ooooo,       OS  Ubuntu 24.04.5 LTS (Noble Numbat) aarch64
     ;oo;:    .coool.       Host  Apple Virtualization Generic Platform (1)
   ....         ''' ,l;     Kernel  Linux 6.8.0-151-generic
  :oooo,            'oo.    Uptime  6 mins
  loooc             :oo'    Packages  764 (dpkg)
   '::'             ,oo:    CPU  Virtualized Apple Silicon (4)
     ,.,       .... co,     Memory  423.16 MiB / 7.74 GiB (5%)
      lo:;.   :oooo; .      Disk (/)  2.69 GiB / 45.45 GiB (6%) - ext4
       ':ooo; cooooc        Local IP (eth0)  192.168.5.15/24
          '''  ''''         Locale  en_US.UTF-8
you@lima-ubuntu:/Users/you$
```

---

## English

### What it is

[Lima](https://lima-vm.io) provides the VM, Apple **Virtualization.framework** provides hardware
acceleration, and the guest is an **aarch64-native** Ubuntu 24.04 LTS — no x86 emulation, so CPU
performance is close to bare metal. `msl` is a thin CLI that gives the whole thing a WSL-like feel.

- Cold start: ~8 s (`msl stop` then `msl`)
- Idle footprint: ~120 MB of macOS RAM (8 GiB is the cap, allocated lazily)
- Disk: ~2.6 GB in use, grows on demand up to 48 GB

### Language

Every message follows the locale (`LC_ALL` → `LC_MESSAGES` → `LANGUAGE` → `LANG`):
a `zh*` locale gets Chinese, anything else gets English. Override with `MSL_LANG`:

```bash
MSL_LANG=en msl --help      # force English
MSL_LANG=zh msl info        # force Chinese
```

### Requirements

- Apple Silicon Mac (M1/M2/M3/M4), macOS 13 or newer
- [Homebrew](https://brew.sh)
- ~3 GB of disk for the first install (image + VM); network access to `cloud-images.ubuntu.com`

### Install

```bash
git clone https://github.com/duhaoze2007/MSL-macOS_Subsystem_Linux.git
cd MSL-macOS_Subsystem_Linux
./install.sh
```

`install.sh` installs Lima, puts `msl` in `~/.local/bin`, and then **drops you straight into
first-time setup** — exactly like the first launch of Ubuntu on Windows:

```
  MSL —— macOS Subsystem for Linux
  First run: create an account for your Ubuntu subsystem.

  Enter new UNIX username: alice
  New password:
  Retype new password:
```

Language follows your locale: a `zh*` locale gets the Chinese version of every message, anything
else gets English. See [Language](#language) to force one.

The account is yours: the VM is created with that username and password. Provisioning
(apt, toolchain, fastfetch) takes about 2 minutes, then you land in your shell. Total ~5 minutes
depending on network speed.

After that, every entry is just:

```bash
msl
```

Non-interactive install, for scripts:

```bash
MSL_USER=alice MSL_PASSWORD='change-me' ./install.sh
```

### Usage

```bash
msl                          # enter Ubuntu (auto-starts, ~8 s from stopped)
msl -c 'apt update'          # run a command through bash (pipes, redirects work)
msl ls -l /                  # run a command directly, no shell
msl -u root -c 'whoami'      # run as another user (root = root shell)
msl -C /tmp -c 'pwd'         # run in a specific directory
wsm -c 'uname -a'            # alias: wsm
ubuntu -c 'uname -a'         # alias: ubuntu
```

If your current directory is inside your Mac home, `msl` carries it into the guest, so you land
in the same directory.

| Command | Purpose |
|---|---|
| `msl setup` | First-time setup (same as running `msl` for the first time) |
| `msl passwd` | Change the current account's password |
| `msl reset` | Delete the instance and run setup again |
| `msl status` | Running state |
| `msl info` | User / distro / kernel / CPU / memory / disk / IP / home |
| `msl start` / `stop` / `restart` | Start/stop; `stop` returns memory to macOS immediately |
| `msl update` | `apt update && apt upgrade` inside the guest |
| `msl list` | All Lima instances |
| `msl create` / `delete` | Create / delete (deletion asks for `yes`) |

Environment variables: `MSL_INSTANCE` (instance name), `MSL_USER` / `MSL_PASSWORD` (skip the
wizard), `MSL_LANG` (zh/en), `MSL_CPUS` / `MSL_MEM` / `MSL_DISK`, `MSL_TEMPLATE` (image template), `MSL_TZ` (timezone).

### Where things live

| Path | Notes |
|---|---|
| `/Users/<you>` | **Mac home**, mounted at the same path, read-write (virtiofs) |
| `/home/<you>` | The guest's Linux home (`~`); apt, configs and dotfiles live here |
| `~/.lima/ubuntu` | VM disk and config (~2.6 GB, grows to a 48 GB cap) |

`sudo` requires a password, same as WSL. The first `apt` will prompt for it.

### Networking

Anything listening inside the guest is forwarded to `127.0.0.1` on macOS:

```bash
msl -c 'cd /srv && nohup python3 -m http.server 8000 </dev/null >/tmp/http.log 2>&1 &'
curl http://127.0.0.1:8000/       # reachable from macOS
```

> Background processes started via `msl -c` **must** redirect stdin (`</dev/null`), otherwise the
> SSH session stays attached to the child and the command never returns.

### Login screen

`msl` runs [fastfetch](https://github.com/fastfetch-cli/fastfetch) on login (it is not in Ubuntu
24.04's repos, so it comes from the official PPA). Config lives in the guest at
`~/.config/fastfetch/config.jsonc`.

To turn it off:

```bash
mv ~/.config/fastfetch/config.jsonc ~/.config/fastfetch/config.jsonc.bak
sudo chmod -x /etc/update-motd.d/00-msl     # disable the banner entirely
```

### Preinstalled

Ubuntu 24.04 LTS (aarch64) plus build-essential / gcc / g++ / cmake / gdb / make, git (+lfs),
python3 (+pip/venv), curl / wget / jq / ripgrep / fd / bat / tree / unzip / rsync,
vim / nano / tmux / htop / btop / strace / lsof, net-tools / iputils-ping / dnsutils, fastfetch,
nasm / lld / qemu-user-static (build and run x86 binaries).
Timezone defaults to `Asia/Kuala_Lumpur`, locale to `en_US.UTF-8`.

Want Docker?

```bash
msl -c 'sudo apt install -y docker.io && sudo usermod -aG docker $USER'
```

### Building x86 assembly

`nasm` is installed, plus everything needed to build and run x86 binaries on an ARM guest:

- `/usr/local/bin/ld` wraps `ld.lld`: when the target is x86 (`-m elf_i386`, or the input is an x86
  object) the call is handed to lld; everything else falls through to the system `ld`. `gcc` is
  unaffected because it invokes `/usr/bin/ld` directly.
- 32-bit binaries run through `qemu-i386` (registered with `binfmt_misc`), so `./prog` just works.
- 64-bit x86 binaries run through Rosetta, which Lima enables with `--rosetta`.

```bash
nasm -f elf32 shapes.asm -o shapes.o
ld -m elf_i386 shapes.o -o shapes     # wrapped -> lld
./shapes                              # plain run -> qemu-i386
```

> Run these interactively. Such programs usually call `read(0, buf, 32)`; a piped stdin is consumed
> in one go, the next read hits EOF and a menu loop spins forever. This is true on native x86 too.

### A second distro

```bash
MSL_INSTANCE=alpine MSL_TEMPLATE=template:alpine msl create
MSL_INSTANCE=alpine msl
```

Instances are independent and share the same `msl` command.

### Uninstall

```bash
msl delete                              # remove the VM (Mac files are untouched)
brew uninstall lima                     # remove the runtime
rm ~/.local/bin/{msl,wsm,ubuntu}        # remove the commands
rm -rf ~/.config/msl ~/.config/fastfetch
```

### Repo layout

```
msl                    main CLI (bash 3.2 compatible — runs on stock macOS bash)
install.sh             one-shot installer
provision/
  provision.sh         guest setup (apt, toolchain, locale, banner; idempotent)
  99-msl.sh            /etc/profile.d shell environment
  00-msl               login banner (fastfetch, plain-text fallback)
  fastfetch.jsonc      fastfetch config
```

Editing `msl` takes effect immediately; after editing the provisioning script, re-run it:

```bash
msl -c 'sudo bash ~/.config/msl/provision.sh'
```

### Why Lima

| Option | Trade-off |
|---|---|
| **Lima** (this project) | Open source, CLI-only, aarch64-native, virtiofs mounts, port forwarding, no GUI dependency |
| OrbStack | Faster, but proprietary; free for personal use, paid for commercial |
| Multipass | Canonical's Ubuntu VMs; QEMU-based and slower, no home-directory sharing |
| Docker Desktop | Containers, not a full Linux environment |

### License

MIT

---

## 中文

### 它是什么

[Lima](https://lima-vm.io) 提供虚拟机，Apple **Virtualization.framework** 提供硬件加速，跑的是
**aarch64 原生** Ubuntu 24.04 LTS——没有 x86 模拟，CPU 性能接近原生。`msl` 只是给这套东西套了
一层 WSL 手感的命令行。

- 冷启动约 8 秒（`msl stop` 之后再 `msl`）
- 空闲时占 macOS 约 120MB 内存（8GiB 是上限，懒分配）
- 磁盘已用约 2.6GB，按需增长到 48GB 上限

### 语言

所有提示跟随 locale（`LC_ALL` → `LC_MESSAGES` → `LANGUAGE` → `LANG`）：
`zh*` 输出中文，其他一律英文。可以用 `MSL_LANG` 强制：

```bash
MSL_LANG=zh msl --help      # 强制中文
MSL_LANG=en msl info        # 强制英文
```

### 要求

- Apple Silicon Mac（M1/M2/M3/M4），macOS 13 以上
- [Homebrew](https://brew.sh)
- 首次安装约 3GB 磁盘（镜像 + 虚拟机），网络能到 `cloud-images.ubuntu.com`

### 安装

```bash
git clone https://github.com/duhaoze2007/MSL-macOS_Subsystem_Linux.git
cd MSL-macOS_Subsystem_Linux
./install.sh
```

`install.sh` 装好 Lima、把 `msl` 放进 `~/.local/bin`，然后**直接进入首次设置**——和 Windows 上
第一次启动 Ubuntu 一模一样：

```
  MSL —— macOS Subsystem for Linux
  第一次使用，先为 Ubuntu 子系统创建账户。

  Enter new UNIX username: alice
  New password:
  Retype new password:
```

账户是你自己定的：虚拟机就用这个用户名和密码创建。接着初始化（apt、工具链、fastfetch）约
2 分钟，完成后落进你的 shell。全程约 5 分钟（看网速）。

之后每次进子系统就一条：

```bash
msl
```

不想交互的话，脚本化安装：

```bash
MSL_USER=alice MSL_PASSWORD='改我' ./install.sh
```

### 用法

```bash
msl                          # 进入 Ubuntu（没运行会自动启动，约 8 秒）
msl -c 'apt update'          # 走 bash 执行命令（支持管道、重定向）
msl ls -l /                  # 直接执行命令，不经 shell
msl -u root -c 'whoami'      # 以指定用户执行（root 即 root shell）
msl -C /tmp -c 'pwd'         # 在指定目录执行
wsm -c 'uname -a'            # 别名：wsm
ubuntu -c 'uname -a'         # 别名：ubuntu
```

当前目录在 Mac 家目录里时，`msl` 会把你带进同一个目录。

| 命令 | 作用 |
|---|---|
| `msl setup` | 首次设置（等价于第一次直接跑 `msl`） |
| `msl passwd` | 改当前账户密码 |
| `msl reset` | 删掉实例重新走一遍设置向导 |
| `msl status` | 运行状态 |
| `msl info` | 用户 / 发行版 / 内核 / CPU / 内存 / 磁盘 / IP / 家目录 |
| `msl start` / `stop` / `restart` | 启停；`stop` 后内存立刻还给 Mac |
| `msl update` | 子系统内 `apt update && apt upgrade` |
| `msl list` | 所有 Lima 实例 |
| `msl create` / `delete` | 创建 / 删除（删除需输入 `yes`） |

环境变量：`MSL_INSTANCE`（实例名）、`MSL_USER` / `MSL_PASSWORD`（跳过向导）、
`MSL_CPUS` / `MSL_MEM` / `MSL_DISK`、`MSL_TEMPLATE`（镜像模板）、`MSL_TZ`（时区）。

### 文件在哪

| 位置 | 说明 |
|---|---|
| `/Users/<你>` | **Mac 家目录**，同一个路径挂进子系统，双向可写（virtiofs） |
| `/home/<你>` | 子系统的 Linux 家目录（`~`），apt、配置和 dotfiles 都在这 |
| `~/.lima/ubuntu` | 虚拟机磁盘与配置（约 2.6GB，按需增长到 48GB 上限） |

`sudo` 需要密码，和 WSL 一样；第一次 `apt` 会提示输入。

### 网络

子系统里监听的服务会自动转发到 Mac 的 `127.0.0.1`：

```bash
msl -c 'cd /srv && nohup python3 -m http.server 8000 </dev/null >/tmp/http.log 2>&1 &'
curl http://127.0.0.1:8000/       # Mac 上直接访问
```

> 在 `msl -c` 里后台起进程**必须**重定向 stdin（`</dev/null`），否则 ssh 会话会被子进程占住，
> 命令一直不返回。

### 登录画面

进 `msl` 时自动跑 [fastfetch](https://github.com/fastfetch-cli/fastfetch)（Ubuntu 24.04 官方源
没有，走官方 PPA）。配置在子系统里的 `~/.config/fastfetch/config.jsonc`。

不想要它：

```bash
mv ~/.config/fastfetch/config.jsonc ~/.config/fastfetch/config.jsonc.bak
sudo chmod -x /etc/update-motd.d/00-msl     # 连横幅一起关
```

### 已装好的东西

Ubuntu 24.04 LTS（aarch64）+ build-essential / gcc / g++ / cmake / gdb / make、git(+lfs)、
python3(+pip/venv)、curl / wget / jq / ripgrep / fd / bat / tree / unzip / rsync、
vim / nano / tmux / htop / btop / strace / lsof、net-tools / iputils-ping / dnsutils、fastfetch、
nasm / lld / qemu-user-static（编译并运行 x86 程序）。
时区默认 `Asia/Kuala_Lumpur`，locale `en_US.UTF-8`。

要 Docker：

```bash
msl -c 'sudo apt install -y docker.io && sudo usermod -aG docker $USER'
```

### 编译 x86 汇编

系统里装了 `nasm`，以及让 ARM 机器能编译、运行 x86 程序的那套东西：

- `/usr/local/bin/ld` 把 x86 目标转给 `ld.lld`（`-m elf_i386`，或输入是 x86 目标文件时），
  其余原样交给系统 `ld`；`gcc` 直连 `/usr/bin/ld`，不受影响。
- 32 位程序由 `qemu-i386` 接管（已注册到 `binfmt_misc`），`./prog` 直接能跑。
- 64 位 x86 程序跑在 Rosetta 上（Lima 用 `--rosetta` 启用）。

```bash
nasm -f elf32 shapes.asm -o shapes.o
ld -m elf_i386 shapes.o -o shapes     # 走 lld
./shapes                              # 走 qemu-i386
```

> 这类程序请在终端里交互式运行。它通常用 `read(0, buf, 32)`，管道会一次性把输入读光，
> 下一次 read 直接 EOF，菜单循环会空转——原生 x86 机器上也一样。

### 再造一个发行版

```bash
MSL_INSTANCE=alpine MSL_TEMPLATE=template:alpine msl create
MSL_INSTANCE=alpine msl
```

实例之间互不影响，共用同一套 `msl` 命令。

### 卸载

```bash
msl delete                              # 删虚拟机（Mac 文件不受影响）
brew uninstall lima                     # 删运行时
rm ~/.local/bin/{msl,wsm,ubuntu}        # 删命令
rm -rf ~/.config/msl ~/.config/fastfetch
```

### 目录结构

```
msl                    主命令（兼容 bash 3.2，macOS 自带 bash 也能跑）
install.sh             一键安装
provision/
  provision.sh         子系统初始化（apt、工具链、locale、横幅；可重复执行）
  99-msl.sh            /etc/profile.d 的 shell 环境
  00-msl               登录横幅（fastfetch 优先，缺失时退回纯文本）
  fastfetch.jsonc      fastfetch 配置
```

改了 `msl` 直接生效；改了初始化脚本要重跑：

```bash
msl -c 'sudo bash ~/.config/msl/provision.sh'
```

### 为什么是 Lima

| 方案 | 取舍 |
|---|---|
| **Lima**（本项目） | 开源、纯 CLI、aarch64 原生、virtiofs 挂载、端口转发、无 GUI 依赖 |
| OrbStack | 更快，但闭源；个人免费、商用收费 |
| Multipass | Canonical 官方的 Ubuntu 虚拟机；底层 QEMU 较慢，不共享家目录 |
| Docker Desktop | 容器，不是完整 Linux 环境 |

### License

MIT
