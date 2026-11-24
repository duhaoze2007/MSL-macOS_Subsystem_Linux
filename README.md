# MSL —— macOS Subsystem for Linux

**MSL** 是 macOS 上的「WSL」：一条命令进出一个 ARM 原生的 Ubuntu 虚拟机，Mac 的文件在子系统里是**同一个路径**、双向可写，端口自动转发。

名字对应 WSL = **W**indows **S**ubsystem for **L**inux，所以 macOS 上是 **M**acOS **S**ubsystem for **L**inux。

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

## 它是什么

[Lima](https://lima-vm.io) 提供虚拟机，Apple **Virtualization.framework** 提供硬件加速，跑的是
**aarch64 原生** Ubuntu 24.04 LTS——没有 x86 模拟，CPU 性能接近原生。
`msl` 只是给这套东西套了一层 WSL 手感的命令行。

## 要求

- Apple Silicon Mac（M1/M2/M3/M4），macOS 13 以上
- [Homebrew](https://brew.sh)
- 首次安装约 3GB 磁盘（镜像 + 虚拟机），网络能到 `cloud-images.ubuntu.com`

## 安装

```bash
git clone https://github.com/duhaoze2007/MSL-macOS_Subsystem_Linux.git
cd MSL-macOS_Subsystem_Linux
./install.sh
```

`install.sh` 装 Lima、把 `msl` 放进 `~/.local/bin`，然后**直接进入首次设置**：

```
  MSL —— macOS Subsystem for Linux
  第一次使用，先为 Ubuntu 子系统创建账户。

  Enter new UNIX username: alice
  New password:
  Retype new password:
```

和 Windows 上第一次启动 Ubuntu 一样——账户是你自己建的，不是脚本替你建的。
设置完自动创建 4 核 / 8GiB / 48GiB 的实例、装好工具链（约 2 分钟），然后落进你的 shell。
全程约 5 分钟（看网速）。

之后每次进子系统：

```bash
msl
```

### 一次性脚本化安装

不想交互也可以直接给账户（密码至少 8 位）：

```bash
MSL_USER=alice MSL_PASSWORD='改我' git clone ... && cd ... && ./install.sh
```

## 用法

```bash
msl                          # 进入 Ubuntu shell（没运行会自动启动，约 8 秒）
msl -c 'apt update'          # 执行一条命令（走 bash，支持管道、重定向）
msl ls -l /                  # 直接执行命令，不经 shell
msl -u root -c 'whoami'      # 以 root 执行
msl -C /tmp -c 'pwd'         # 在指定目录执行
wsm -c 'uname -a'            # 别名：wsm
ubuntu -c 'uname -a'         # 别名：ubuntu
```

当前目录在 Mac 家目录里时，`msl` 会把你**带进同一个目录**，不用 `cd`。

| 子命令 | 作用 |
|---|---|
| `msl setup` | 首次设置（等价于第一次直接跑 `msl`） |
| `msl passwd` | 改当前账户密码 |
| `msl reset` | 删掉实例重新走一遍设置向导 |
| `msl status` | 运行状态 |
| `msl info` | 用户 / 发行版 / 内核 / CPU / 内存 / 磁盘 / IP / 家目录 |
| `msl start` / `stop` / `restart` | 启停，`stop` 后内存立刻还给 Mac |
| `msl update` | 子系统内 `apt update && apt upgrade` |
| `msl list` | 所有 Lima 实例 |
| `msl create` / `delete` | 创建 / 删除（删除需输入 `yes`） |

环境变量：`MSL_INSTANCE`（实例名）、`MSL_USER` / `MSL_PASSWORD`（跳过向导）、
`MSL_CPUS` / `MSL_MEM` / `MSL_DISK`、`MSL_TEMPLATE`（创建时的模板）、`MSL_TZ`（时区）。

## 文件在哪

| 位置 | 说明 |
|---|---|
| `/Users/<你>` | **Mac 家目录**，同一个路径挂进子系统，双向可写（virtiofs） |
| `/home/<你>` | 子系统的 Linux 家目录（`~`），`apt`、配置文件都在这 |
| `~/.lima/ubuntu` | 虚拟机磁盘与配置（约 2.6GB 起，上限 48GB，按需增长） |

`sudo` 需要密码（和 WSL 一样），第一次 `apt` 会提示输入。

## 网络

子系统里监听的服务自动转发到 Mac 的 `127.0.0.1`：

```bash
msl -c 'cd /srv && nohup python3 -m http.server 8000 </dev/null >/tmp/http.log 2>&1 &'
curl http://127.0.0.1:8000/       # Mac 上直接访问
```

> 在 `msl -c` 里后台起进程**必须重定向 stdin**（`</dev/null`），否则 ssh 会话会被子进程占住，命令不返回。

## 登录画面

进 `msl` 时自动跑 [fastfetch](https://github.com/fastfetch-cli/fastfetch)（Ubuntu 24.04 官方源没有，走官方 PPA）。
配置在子系统里的 `~/.config/fastfetch/config.jsonc`。

不想要它：

```bash
mv ~/.config/fastfetch/config.jsonc ~/.config/fastfetch/config.jsonc.bak
sudo chmod -x /etc/update-motd.d/00-msl     # 连横幅一起关
```

## 已装好的软件

Ubuntu 24.04 LTS（aarch64）+ build-essential / gcc / g++ / cmake / gdb / make、
git(+lfs)、python3(+pip/venv)、curl / wget / jq / ripgrep / fd / bat / tree /
unzip / rsync、vim / nano / tmux / htop / btop / strace / lsof、
net-tools / iputils-ping / dnsutils、fastfetch。
时区默认 `Asia/Kuala_Lumpur`，locale `en_US.UTF-8`。

要 Docker：

```bash
msl -c 'sudo apt install -y docker.io && sudo usermod -aG docker $USER'
```

## 再造一个发行版

```bash
MSL_INSTANCE=alpine MSL_TEMPLATE=template:alpine msl create
MSL_INSTANCE=alpine msl
```

实例之间互不影响，共用同一套 `msl` 命令。

## 卸载

```bash
msl delete                              # 删虚拟机（Mac 文件不受影响）
brew uninstall lima                     # 删运行时
rm ~/.local/bin/{msl,wsm,ubuntu}        # 删命令
rm -rf ~/.config/msl ~/.config/fastfetch
```

## 目录结构

```
msl                    主命令（bash 3.2 兼容，macOS 自带 bash 也能跑）
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

## 为什么是 Lima

| 方案 | 取舍 |
|---|---|
| **Lima**（本项目） | 开源、纯 CLI、aarch64 原生、virtiofs 挂载、端口转发、无 GUI 依赖 |
| OrbStack | 更快，但闭源、个人免费商用收费 |
| Multipass | Canonical 官方，底层 QEMU 较慢，不共享家目录 |
| Docker Desktop | 容器而非完整 Linux 环境 |

## License

MIT
