# syntax=docker/dockerfile:1
#
# Базовый образ Jetson Orin Nano (JP7-класс): CUDA 13 + Ubuntu 24.04 + ROS2 Jazzy.
#
# ВНИМАНИЕ: официального l4t-образа под JP7 ещё НЕ выпущено (на нач. 2026 latest
# l4t-jetpack = r36.4.0). Поэтому базой взят официальный мульти-арх CUDA-образ
# nvidia/cuda под Ubuntu 24.04 (arm64) — это JP7-совместимый стек (CUDA 13 / U24.04).
# Когда NVIDIA выпустит l4t под r38 — можно будет просто заменить FROM.
#
# JP7 = Ubuntu 24.04 => ROS2 Jazzy (не Humble). Установка ROS2 — через ОБЩИЙ
# scripts/install_ros2.sh (параметризован дистрибутивом). Поэтому для этой платформы
# build-контекст = корень репозитория (см. .github/workflows/build.yml, поля context/file).

ARG BASE_CUDA=13.1.0-devel-ubuntu24.04
FROM nvidia/cuda:${BASE_CUDA}

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=en_US.UTF-8 \
    ROS_DISTRO=jazzy

# Единый установщик ROS2 (тот же референс, что для x86/AGX) — с дистрибутивом jazzy.
COPY scripts/install_ros2.sh /tmp/install_ros2.sh
RUN bash /tmp/install_ros2.sh jazzy && rm -f /tmp/install_ros2.sh

SHELL ["/bin/bash", "-c"]
CMD ["bash"]