#!/usr/bin/env bash
#
# Локальная сборка образов (база + пакет + smoke-тест) для выбранной платформы.
# Использование: bash scripts/build_local.sh [x86|jetson-agx]   (по умолчанию x86)
#
# ПРИМЕЧАНИЕ: jetson-agx собирается под ARM64 — на x86-хосте это идёт через QEMU
# (медленно, нужен настроенный buildx/binfmt). Локально практичнее x86;
# ARM-сборки лучше гонять в CI (см. .github/workflows/build.yml).
set -euo pipefail

PLATFORM="${1:-x86}"
OWNER="ilyasalih"

case "$PLATFORM" in
  x86)
    BASE=ghcr.io/$OWNER/ros2-cuda-x86:humble-cuda12.6
    PKG=ghcr.io/$OWNER/fast-lio2-x86:humble-cuda12.6
    BASE_CTX=docker/base/x86
    CUDA_ARCH=89
    ;;
  jetson-agx)
    BASE=ghcr.io/$OWNER/ros2-cuda-jetson-agx:humble-l4t-r36.4
    PKG=ghcr.io/$OWNER/fast-lio2-jetson-agx:humble-l4t-r36.4
    BASE_CTX=docker/base/jetson-agx
    CUDA_ARCH=87
    ;;
  *)
    echo "Неизвестная платформа: $PLATFORM (доступно: x86 | jetson-agx)"; exit 1 ;;
esac

echo "=== [1/3] Сборка базы: $BASE ==="
docker build -t "$BASE" "$BASE_CTX"

echo "=== [2/3] Сборка пакета FAST-LIO2: $PKG ==="
docker build \
  --build-arg BASE_IMAGE="$BASE" \
  --build-arg CUDA_ARCHITECTURES="$CUDA_ARCH" \
  -t "$PKG" docker/package

echo "=== [3/3] Smoke-тест образа ==="
bash tests/test_image.sh "$PKG"

echo "=== Готово: $BASE  +  $PKG ==="