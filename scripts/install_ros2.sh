#!/usr/bin/env bash
#
# Установщик ROS2 + системных зависимостей для сборки ROS2-пакетов.
# Дистрибутив передаётся аргументом:
#   humble  — Ubuntu 22.04 (x86-база, Jetson AGX / JP6.2.2)
#   jazzy   — Ubuntu 24.04 (Jetson Orin Nano / JP7)
#
# Это единый источник правды для установки ROS2. Базовые Dockerfile'ы сейчас
# держат ту же логику инлайн; при желании их можно перевести на этот скрипт
# (см. docs/add-package.md) — тогда добавление платформы = FROM + вызов install_ros2.sh.
# Скрипт также можно запустить на «голой» Ubuntu для настройки dev-машины.
#
# Использование:
#   ./install_ros2.sh humble
#   (в Dockerfile):  COPY scripts/install_ros2.sh /tmp/  &&  RUN /tmp/install_ros2.sh humble
set -eux

ROS_DISTRO="${1:?Использование: install_ros2.sh <ros_distro>  (humble | jazzy)}"
export DEBIAN_FRONTEND=noninteractive

# --- Локаль + базовые инструменты ---
apt-get update
apt-get install -y --no-install-recommends \
    locales curl gnupg2 ca-certificates lsb-release software-properties-common \
    git wget build-essential cmake
locale-gen en_US en_US.UTF-8
update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8

# --- Репозиторий ROS2 (пакет ros2-apt-source), с таймаутами/форсом IPv4 ---
add-apt-repository universe
ROS_APT_SOURCE_VERSION=$(curl -4 -s --connect-timeout 15 --max-time 60 \
    --retry 5 --retry-connrefused \
    https://api.github.com/repos/ros-infrastructure/ros-apt-source/releases/latest \
    | grep -F '"tag_name"' | awk -F'"' '{print $4}')
curl -4 -L --connect-timeout 15 --max-time 120 --retry 5 --retry-connrefused \
    -o /tmp/ros2-apt-source.deb \
    "https://github.com/ros-infrastructure/ros-apt-source/releases/download/${ROS_APT_SOURCE_VERSION}/ros2-apt-source_${ROS_APT_SOURCE_VERSION}.$(. /etc/os-release && echo "$VERSION_CODENAME")_all.deb"
dpkg -i /tmp/ros2-apt-source.deb
rm -f /tmp/ros2-apt-source.deb

# --- Устойчивость apt (ретраи + сохранение .deb между попытками) ---
rm -f /etc/apt/apt.conf.d/docker-clean
printf '%s\n' \
    'Acquire::Retries "8";' \
    'Acquire::http::Timeout "60";' \
    'Acquire::https::Timeout "60";' \
    'Acquire::ForceIPv4 "true";' \
    'APT::Keep-Downloaded-Packages "true";' \
    > /etc/apt/apt.conf.d/99network-resilience

# --- ROS2 (base) + инструменты сборки, с ретрай-циклом (packages.ros.org может лимитировать) ---
apt-get update
ok=0
for i in $(seq 1 10); do
    echo "=== ROS2 (${ROS_DISTRO}) install: попытка $i/10 ==="
    if apt-get install -y --no-install-recommends \
        ros-${ROS_DISTRO}-ros-base \
        ros-${ROS_DISTRO}-perception-pcl \
        ros-${ROS_DISTRO}-pcl-conversions \
        ros-dev-tools \
        python3-colcon-common-extensions \
        python3-rosdep \
        libeigen3-dev ; then
        ok=1; break
    fi
    echo "--- попытка $i не добрала пакеты, пауза 30с ---"; sleep 30
done
[ "$ok" = "1" ]
rosdep init || true    # уже может быть инициализирован в базовом образе
rosdep update
rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*.deb

# --- Автосорс окружения ROS2 в интерактивной оболочке ---
echo "source /opt/ros/${ROS_DISTRO}/setup.bash" >> /etc/bash.bashrc
echo "=== ROS2 ${ROS_DISTRO} установлен ==="