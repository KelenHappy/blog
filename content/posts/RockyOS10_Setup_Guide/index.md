---
title: "Rocky Linux Setup"
date: 2026-07-31
draft: false
descrition: "首次設定教學"
---
# 前言
Rocky Linux 是由 Rocky Enterprise Software Foundation（RESF）維護，目標是提供與 Red Hat Enterprise Linux（RHEL）高度相容的作業系統，因此在企業、研究機構以及 HPC（High Performance Computing）環境都十分常見。

為什麼不用 Ubuntu？ 我們的 GPU Server 幾乎都採用最新一代 CPU 與 NVIDIA 顯示卡，因此需要較新的 Linux Kernel、驅動程式與 CUDA 支援。Rocky Linux 10 已採用 Linux 6.12 LTS 核心，對新硬體的支援相當完整，同時維持 Enterprise Linux 的穩定性。配合 CRB、EPEL 以及 NVIDIA 官方 Repository，即可取得最新驅動與 [CUDA Toolkit](https://developer.nvidia.com/cuda-downloads?target_os=Linux&target_arch=x86_64&Distribution=Rocky&target_version=10&target_type=rpm_network)，因此成為目前部署 GPU Server 的首選。

# Rocky Linux 10 GPU Server 初次安裝
## 從頭開始

## 1. 更新系統

```bash
sudo dnf upgrade --refresh -y
sudo reboot
```

---

## 2. 啟用 SSH 並開放 22 Port

```bash
sudo systemctl enable --now sshd

sudo firewall-cmd --permanent --add-service=ssh
sudo firewall-cmd --reload
```

確認：

```bash
sudo ss -lntp | grep ':22'
```

---

## 3. 啟用 CRB 與 EPEL

```bash
sudo dnf install -y dnf-plugins-core

sudo dnf config-manager --set-enabled crb
sudo dnf install -y epel-release

sudo dnf upgrade --refresh -y
```

確認：

```bash
dnf repolist | grep -E 'crb|epel'
```

Rocky Linux 10 使用 EPEL 前應啟用 CRB。

---

## 4. 安裝常用 Server 套件

```bash
sudo dnf group install -y "Development Tools"
```

```bash
sudo dnf install -y \
  micro \
  uv \
  gcc \
  gcc-c++ \
  make \
  cmake \
  ninja-build \
  pkgconf-pkg-config \
  dkms \
  kernel-devel-matched \
  kernel-headers \
  git \
  git-lfs \
  curl \
  wget \
  tmux \
  htop \
  tree \
  jq \
  rsync \
  unzip \
  zip \
  tar \
  bash-completion \
  pciutils \
  usbutils \
  lsof \
  bind-utils \
  net-tools \
  iproute \
  iputils \
  openssl \
  openssl-devel \
  python3 \
  python3-pip \
  podman
```

`micro` 與 `uv` 都由 EPEL 10 提供，可直接使用 DNF 管理。

確認：

```bash
micro --version
uv --version
gcc --version
make --version
podman --version
```

---

## 5. 確認 NVIDIA GPU

```bash
lspci | grep -i nvidia
```

---

## 6. 停用 Nouveau

```bash
sudo tee /etc/modprobe.d/blacklist-nouveau.conf >/dev/null <<'EOF'
blacklist nouveau
options nouveau modeset=0
EOF
```

```bash
sudo dracut --force
sudo reboot
```

重新登入後確認沒有載入 Nouveau：

```bash
lsmod | grep nouveau
```

沒有輸出即可。

---

## 7. 加入 NVIDIA 官方 Repository

```bash
sudo dnf config-manager --add-repo \
https://developer.download.nvidia.com/compute/cuda/repos/rhel10/x86_64/cuda-rhel10.repo
```

```bash
sudo dnf clean all
sudo dnf makecache
```

確認：

```bash
dnf repolist | grep cuda
```

---

## 8. 安裝最新 NVIDIA Open Driver

RTX 3080 Ti 以上使用 Open Kernel Module：

```bash
sudo dnf install -y \
  nvidia-driver-cuda \
  kmod-nvidia-open-dkms
```

這是 NVIDIA 對 Rocky Linux 9／10 文件列出的安裝組合。

重新開機：

```bash
sudo reboot
```

確認：

```bash
nvidia-smi
```

查看驅動版本：

```bash
nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv
```

---

## 9. 安裝最新 CUDA Toolkit

安裝 NVIDIA repository 當下的最新版本：

```bash
sudo dnf install -y cuda-toolkit
```

目前會安裝 CUDA Toolkit 13.3 系列；`cuda-toolkit` 之後也會隨 repository 升級至新的主要版本。

設定環境：

```bash
sudo tee /etc/profile.d/cuda.sh >/dev/null <<'EOF'
export PATH=/usr/local/cuda/bin:$PATH
export LD_LIBRARY_PATH=/usr/local/cuda/lib64:$LD_LIBRARY_PATH
EOF
```

```bash
source /etc/profile.d/cuda.sh
```

確認：

```bash
nvcc --version
nvidia-smi
```

需要固定在 CUDA 13 系列、不自動跳到 CUDA 14 時，可改裝：

```bash
sudo dnf install -y cuda-toolkit-13
```

需要固定在 13.3：

```bash
sudo dnf install -y cuda-toolkit-13-3
```

---

## 10. 測試 Podman

```bash
podman run --rm docker.io/library/alpine:latest cat /etc/os-release
```

這裡只安裝真正的 Podman，沒有安裝：

```text
docker
docker-ce
podman-docker
```

---

## 11. 最後完整檢查

```bash
cat /etc/rocky-release
uname -r

dnf repolist | grep -E 'crb|epel|cuda'

sudo ss -lntp | grep ':22'

micro --version
uv --version
gcc --version
make --version
podman --version

nvidia-smi
nvcc --version
```

正常結果應包含：

```text
SSH：TCP 22 正在監聽
CRB：已啟用
EPEL：已啟用
micro：可執行
uv：可執行
Podman：可執行
NVIDIA Driver：nvidia-smi 正常
CUDA Toolkit：nvcc 正常
```

## 日後更新

```bash
sudo dnf upgrade --refresh -y
sudo reboot
```

更新並重新開機後檢查：

```bash
nvidia-smi
nvcc --version
podman --version
```
