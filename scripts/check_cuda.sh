#!/usr/bin/env bash
#
# Быстрая проверка CUDA-стека в образе: nvcc + библиотеки + компиляция .cu.
# GPU не требуется (компиляция уже доказывает рабочий тулчейн).
# Использование: bash scripts/check_cuda.sh [образ]
set -uo pipefail

IMAGE="${1:-ghcr.io/ilyasalih/ros2-cuda-x86:humble-cuda12.6}"
SMOKE_DIR="$(cd "$(dirname "$0")/.." && pwd)/tests/cuda-smoke"

echo "=== CUDA check: $IMAGE ==="
docker run --rm -v "$SMOKE_DIR":/smoke:ro "$IMAGE" bash -c '
  set -e
  nvcc --version | tail -n 2
  nvcc /smoke/vector_add.cu -o /tmp/va && echo "OK: nvcc скомпилировал .cu -> CUDA-тулчейн рабочий"
  ls /usr/local/cuda/lib64/libcudart.so* >/dev/null && echo "OK: libcudart на месте"
'
echo "=== CUDA OK ==="