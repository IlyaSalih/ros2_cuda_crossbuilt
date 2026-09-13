#!/usr/bin/env bash
#
# Smoke-тест собранного образа: доказывает рабочий CUDA-стек и наличие ROS2.
# CUDA подтверждается КОМПИЛЯЦИЕЙ .cu через nvcc (GPU не требуется).
#
# Запуск:  bash tests/test_image.sh [образ]
# По умолчанию проверяется образ пакета FAST-LIO2.

set -uo pipefail

IMAGE="${1:-ghcr.io/ilyasalih/fast-lio2-x86:humble-cuda12.6}"
SMOKE_DIR="$(cd "$(dirname "$0")" && pwd)/cuda-smoke"

echo "=== Smoke-тест образа: $IMAGE ==="

# ВНИМАНИЕ: без set -e внутри — иначе `source setup.bash` (ROS) обрывает скрипт.
if docker run --rm -v "$SMOKE_DIR":/smoke:ro "$IMAGE" bash -c '
  rc=0

  echo "--- 1. nvcc присутствует ---"
  nvcc --version | tail -n 2 || rc=1

  echo "--- 2. компиляция CUDA-сэмпла (доказательство тулчейна) ---"
  if nvcc /smoke/vector_add.cu -o /tmp/vector_add; then
    echo "OK: nvcc собрал бинарник -> CUDA-тулчейн рабочий"
  else
    echo "FAIL: nvcc не смог скомпилировать .cu"; rc=1
  fi

  echo "--- 3. запуск сэмпла (GPU может отсутствовать в VM — это ок) ---"
  /tmp/vector_add || true

  echo "--- 4. CUDA-библиотеки в образе ---"
  if ls /usr/local/cuda/lib64/libcudart.so* >/dev/null 2>&1; then
    echo "OK: libcudart на месте"
  else
    echo "FAIL: libcudart не найден"; rc=1
  fi

  echo "--- 5. ROS2 + пакеты ---"
  source /root/ros2_ws/install/setup.bash
  PKGS=$(ros2 pkg list 2>/dev/null)
  if echo "$PKGS" | grep -qx fast_lio; then
    echo "OK: пакет fast_lio собран"
  else
    echo "FAIL: пакет fast_lio не найден"; rc=1
  fi
  if echo "$PKGS" | grep -qx livox_ros_driver2; then
    echo "OK: пакет livox_ros_driver2 собран"
  else
    echo "FAIL: пакет livox_ros_driver2 не найден"; rc=1
  fi

  exit $rc
'; then
  echo "=== SMOKE TEST PASSED ==="
else
  echo "=== SMOKE TEST FAILED ==="
  exit 1
fi