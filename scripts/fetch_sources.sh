#!/usr/bin/env bash
#
# Готовит исходники ROS2-пакетов в docker/package/src/ для COPY в образ.
#
# Два режима:
#  1) Скачивает тарболы сам (curl). ВНИМАНИЕ: GitHub-архивы не поддерживают
#     докачку, каждый заход тянет файл целиком — на рваном канале может не осилить.
#  2) Если положить готовые тарболы в $TMP_DIR с нужными именами (например,
#     скачав их на Windows-хосте), скрипт их ПОДХВАТИТ и просто распакует.
#
# Запуск из корня проекта:  bash scripts/fetch_sources.sh

set -euo pipefail

SRC_DIR="docker/package/src"
TMP_DIR="/tmp/ros2_src_dl"
FASTLIO_BRANCH="main"
LIVOX_BRANCH="master"
IKD_COMMIT="e2e3f4e9d3b95a9e66b1ba83dc98d4a05ed8a3c4"

mkdir -p "$TMP_DIR"

# Ожидаемые имена файлов в $TMP_DIR (для ручной подкладки):
#   fastlio.tar.gz   ikd.tar.gz   livox.tar.gz

dl() {  # dl <url> <out>
  # Если файл уже есть и это валидный tar.gz — не качаем (ручная подкладка/успех).
  if [ -s "$2" ] && tar -tzf "$2" >/dev/null 2>&1; then
    echo ">>> $2 уже есть и валиден — пропускаю загрузку"
    return 0
  fi
  echo ">>> качаю $1"
  curl -4 -fL --retry 30 --retry-all-errors --retry-delay 5 \
       --connect-timeout 20 --speed-limit 2000 --speed-time 20 \
       -o "$2" "$1"
}

rm -rf "$SRC_DIR"
mkdir -p "$SRC_DIR/FAST_LIO_ROS2" "$SRC_DIR/livox_ros_driver2"

# 1. FAST_LIO_ROS2
dl "https://github.com/Ericsii/FAST_LIO_ROS2/archive/refs/heads/${FASTLIO_BRANCH}.tar.gz" "$TMP_DIR/fastlio.tar.gz"
tar -xzf "$TMP_DIR/fastlio.tar.gz" -C "$SRC_DIR/FAST_LIO_ROS2" --strip-components=1

# 2. ikd-Tree (сабмодуль -> include/ikd-Tree)
dl "https://github.com/hku-mars/ikd-Tree/archive/${IKD_COMMIT}.tar.gz" "$TMP_DIR/ikd.tar.gz"
rm -rf "$SRC_DIR/FAST_LIO_ROS2/include/ikd-Tree"
mkdir -p "$SRC_DIR/FAST_LIO_ROS2/include/ikd-Tree"
tar -xzf "$TMP_DIR/ikd.tar.gz" -C "$SRC_DIR/FAST_LIO_ROS2/include/ikd-Tree" --strip-components=1

# 3. livox_ros_driver2
dl "https://github.com/Livox-SDK/livox_ros_driver2/archive/refs/heads/${LIVOX_BRANCH}.tar.gz" "$TMP_DIR/livox.tar.gz"
tar -xzf "$TMP_DIR/livox.tar.gz" -C "$SRC_DIR/livox_ros_driver2" --strip-components=1

echo ""
echo "=== Готово. Содержимое $SRC_DIR: ==="
ls -la "$SRC_DIR"
echo "--- ikd-Tree: ---"
ls "$SRC_DIR/FAST_LIO_ROS2/include/ikd-Tree" | head