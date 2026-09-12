# syntax=docker/dockerfile:1
#
# Базовый x86_64 образ: ROS2 Humble + CUDA Toolkit + системные зависимости.
# Пакет (FAST-LIO2) собирается отдельным Dockerfile поверх этого образа.
#
# Проверь актуальный тег на https://hub.docker.com/r/nvidia/cuda/tags

ARG CUDA_VERSION=12.6.2
FROM nvidia/cuda:${CUDA_VERSION}-devel-ubuntu22.04

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

# --- Репозиторий ROS2 (пакет ros2-apt-source) ---
# curl -4 : форс IPv4 (IPv6 в Docker+VirtualBox часто вешает соединение с GitHub).
# packages.ros.org оставляем на http — по https у него битый TLS-сертификат.
RUN add-apt-repository universe \
    && ROS_APT_SOURCE_VERSION=$(curl -4 -s --connect-timeout 15 --max-time 60 \
         --retry 5 --retry-connrefused \
         https://api.github.com/repos/ros-infrastructure/ros-apt-source/releases/latest \
         | grep -F '"tag_name"' | awk -F'"' '{print $4}') \
    && echo "ros2-apt-source version: ${ROS_APT_SOURCE_VERSION}" \
    && curl -4 -L --connect-timeout 15 --max-time 120 --retry 5 --retry-connrefused \
         -o /tmp/ros2-apt-source.deb \
         "https://github.com/ros-infrastructure/ros-apt-source/releases/download/${ROS_APT_SOURCE_VERSION}/ros2-apt-source_${ROS_APT_SOURCE_VERSION}.$(. /etc/os-release && echo $VERSION_CODENAME)_all.deb" \
    && dpkg -i /tmp/ros2-apt-source.deb \
    && rm /tmp/ros2-apt-source.deb

# --- Устойчивость apt + сохранение уже скачанных .deb между попытками ---
# Убираем docker-clean, чтобы apt НЕ удалял скачанные пакеты — тогда ретрай
# докачивает только недостающее, а не всё заново.
RUN rm -f /etc/apt/apt.conf.d/docker-clean \
    && printf '%s\n' \
        'Acquire::Retries "8";' \
        'Acquire::http::Timeout "60";' \
        'Acquire::https::Timeout "60";' \
        'Acquire::ForceIPv4 "true";' \
        'APT::Keep-Downloaded-Packages "true";' \
        > /etc/apt/apt.conf.d/99network-resilience

# --- ROS2 Humble (base) + инструменты сборки, с ретрай-циклом ---
# packages.ros.org любит банить за массовую закачку. Поэтому: обновляем индекс
# один раз, затем до 10 попыток установки с паузой 30с — apt копит уже
# скачанные .deb и на каждом заходе тянет только оставшиеся.
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
         echo "--- попытка $i не добрала пакеты (ROS-репо мог throttle-нуть), пауза 30с ---" ; \
         sleep 30 ; \
       done \
    && [ "$ok" = "1" ] \
    && rosdep init \
    && rosdep update \
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*.deb

# --- Автоматический source окружения ROS2 в интерактивной оболочке ---
RUN echo "source /opt/ros/${ROS_DISTRO}/setup.bash" >> /etc/bash.bashrc

SHELL ["/bin/bash", "-c"]
CMD ["bash"]