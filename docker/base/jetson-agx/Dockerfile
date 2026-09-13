# syntax=docker/dockerfile:1
#
# Базовый образ Jetson AGX Orin: L4T (JetPack) + ROS2 Humble.
#
# ПЛАТФОРМА ARM64. Собирать через `docker buildx --platform linux/arm64`
# (QEMU на x86-хосте) ИЛИ на нативном ARM64-раннере.
#
# Тега l4t-jetpack:r36.5.0 НЕ существует; r36.4.0 совместим с L4T 36.5
# (JetPack 6.2.2). l4t-jetpack уже содержит CUDA/cuDNN/TensorRT, база на
# Ubuntu 22.04 (jammy) — поэтому ROS2 Humble ставится как на x86,
# а отдельная установка CUDA не нужна.

ARG L4T_VERSION=r36.4.0
FROM nvcr.io/nvidia/l4t-jetpack:${L4T_VERSION}

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=en_US.UTF-8 \
    ROS_DISTRO=humble

# --- Локаль + базовые инструменты ---
RUN apt-get update && apt-get install -y --no-install-recommends \
        locales curl gnupg2 ca-certificates lsb-release \
        software-properties-common \
        git wget build-essential cmake \
    && locale-gen en_US en_US.UTF-8 \
    && update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8 \
    && rm -rf /var/lib/apt/lists/*

# --- Репозиторий ROS2 (пакет ros2-apt-source), с таймаутами/IPv4 ---
RUN add-apt-repository universe \
    && ROS_APT_SOURCE_VERSION=$(curl -4 -s --connect-timeout 15 --max-time 60 \
         --retry 5 --retry-connrefused \
         https://api.github.com/repos/ros-infrastructure/ros-apt-source/releases/latest \
         | grep -F '"tag_name"' | awk -F'"' '{print $4}') \
    && curl -4 -L --connect-timeout 15 --max-time 120 --retry 5 --retry-connrefused \
         -o /tmp/ros2-apt-source.deb \
         "https://github.com/ros-infrastructure/ros-apt-source/releases/download/${ROS_APT_SOURCE_VERSION}/ros2-apt-source_${ROS_APT_SOURCE_VERSION}.$(. /etc/os-release && echo $VERSION_CODENAME)_all.deb" \
    && dpkg -i /tmp/ros2-apt-source.deb \
    && rm /tmp/ros2-apt-source.deb

# --- Устойчивость apt (ретраи + сохранение .deb между попытками) ---
RUN rm -f /etc/apt/apt.conf.d/docker-clean \
    && printf '%s\n' \
        'Acquire::Retries "8";' \
        'Acquire::http::Timeout "60";' \
        'Acquire::https::Timeout "60";' \
        'Acquire::ForceIPv4 "true";' \
        'APT::Keep-Downloaded-Packages "true";' \
        > /etc/apt/apt.conf.d/99network-resilience

# --- ROS2 Humble (base) + инструменты сборки, с ретрай-циклом ---
RUN apt-get update \
    && ok=0 \
    && for i in $(seq 1 10); do \
         echo "=== ROS2 install: попытка $i/10 ===" ; \
         apt-get install -y --no-install-recommends \
             ros-humble-ros-base \
             ros-humble-perception-pcl \
             ros-humble-pcl-conversions \
             ros-dev-tools \
             python3-colcon-common-extensions \
             python3-rosdep \
             libeigen3-dev \
         && { ok=1; break; } ; \
         echo "--- попытка $i не добрала пакеты, пауза 30с ---" ; sleep 30 ; \
       done \
    && [ "$ok" = "1" ] \
    && rosdep init \
    && rosdep update \
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*.deb

# --- Автосорс окружения ROS2 ---
RUN echo "source /opt/ros/${ROS_DISTRO}/setup.bash" >> /etc/bash.bashrc

SHELL ["/bin/bash", "-c"]
CMD ["bash"]