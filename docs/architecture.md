# Архитектура системы сборки

## Цель
Кросс-платформенная сборка Docker-образов для ROS2-пакетов с поддержкой CUDA
под три платформы, с публикацией в реестр и автоматизацией через CI/CD.

## Целевые платформы
| Платформа | CPU | GPU (compute cap.) | Базовый образ | ROS2 |
|-----------|-----|--------------------|---------------|------|
| x86_64 + NVIDIA dGPU | x86_64 | зависит от карты (RTX 4060 = sm_89) | `nvidia/cuda:12.6.2-devel-ubuntu22.04` | Humble |
| Jetson AGX Orin (JP 6.2.2 / L4T R36.5) | ARM64 | Ampere sm_87 | `nvcr.io/nvidia/l4t-jetpack:r36.4.0` | Humble |
| Jetson Orin Nano (JP 7-класс) | ARM64 | Ampere sm_87 | `nvidia/cuda:13.1.0-devel-ubuntu24.04` | Jazzy |

Ключевые различия:
- **x86** использует настольные образы `nvidia/cuda`; **Jetson AGX** — L4T-образы NVIDIA
  (`nvcr.io/nvidia/l4t-*`), привязанные к версии JetPack.
- Для JP 6.2.2 тега `l4t-jetpack:r36.5.0` нет; используется `r36.4.0` (совместим, содержит CUDA/cuDNN/TensorRT).
- **Orin Nano / JP7:** официального l4t-образа под JP7 (r38) ещё не выпущено, поэтому базой взят
  совместимый мульти-арх `nvidia/cuda` под Ubuntu 24.04 (CUDA 13). Когда NVIDIA выпустит l4t r38 — можно заменить FROM.
- **CUDA-архитектура** (`sm_*`) различается и передаётся аргументом `CUDA_ARCHITECTURES` (x86 = 89, Orin = 87).
- **Дистрибутив ROS2** зависит от Ubuntu базы: 22.04 → Humble (x86, AGX Orin), 24.04 → Jazzy (Orin Nano JP7).

## Стратегия сборки (двухслойная)
1. **Базовые образы** (`docker/base/<platform>/`) — ROS2 + CUDA Toolkit + системные зависимости.
   Логика установки ROS2 вынесена в `scripts/install_ros2.sh` (параметризована дистрибутивом:
   `humble` для x86/AGX, `jazzy` для Orin Nano) — единый источник правды.
2. **Слой пакета** (`docker/package/`) — **один универсальный Dockerfile**, собирает ROS2-пакет
   ПОВЕРХ выбранной базы. Аргументы: `BASE_IMAGE`, `FASTLIO_REPO`, `FASTLIO_BRANCH`, `CUDA_ARCHITECTURES`.
   Дистрибутив ROS2 берётся из переменной `ROS_DISTRO` базы (не хардкодится).

## Кросс-компиляция ARM64 (два способа, требование 3.4)
- **Нативно** на ARM64-раннере GitHub (`runs-on: ubuntu-24.04-arm`) — без эмуляции, быстро (~5 мин базы).
- **Кросс** на x86 через `docker buildx` + QEMU (`setup-qemu-action`, `platforms: linux/arm64`) — портируемо,
  но медленно из-за эмуляции (~30 мин базы). Тяжёлые сборки (компиляция C++ пакета) — только нативно.

## CUDA и её подтверждение
FAST-LIO2 сам по себе CPU-only, но образы содержат полный CUDA-стек. Подтверждение — на уровне сборки:
`nvcc --version`, наличие библиотек в `/usr/local/cuda/lib64` и компиляция тестового `.cu`
(`tests/cuda-smoke/vector_add.cu`). Рантайм на GPU требует хоста с видеокартой и `nvidia-container-toolkit`.

## Особенность Jazzy (Orin Nano)
ROS2 Jazzy (rclcpp) требует стандарт C++17, а FAST-LIO2 (Humble-пакет) жёстко ставит C++14
в своём `CMakeLists.txt`. В `docker/package/Dockerfile` для Jazzy применяется патч: замена C++14 → C++17
в CMakeLists перед `colcon build`. Для Humble-платформ патч безвреден (C++17 совместим).

## CI/CD (GitHub Actions)
Единый пайплайн `.github/workflows/build.yml`:
- **Триггеры:** push в `main`/`master`, тег `v*`, ручной запуск.
- **Джобы:**
  - `build-base` — матрица нативных баз (x86, Jetson AGX, Jetson Nano) → канонические теги.
  - `build-base-cross-qemu` — Jetson AGX база через QEMU (второй способ), независимо.
  - `build-package` — матрица пакетов (x86, AGX, Nano) `needs: build-base`, + шаг **теста образа** на своей арке.
- **Кеширование** слоёв через `type=gha` (раздельные scope на ячейку, `ignore-error=true` для устойчивости).
- **Публикация** в ghcr.io через встроенный `GITHUB_TOKEN`.

Порядок `build-base → build-package` обязателен: пакет собирается `FROM <база>`, база должна уже быть в реестре.

## Текущий статус
- [x] x86: база + FAST-LIO2, опубликованы, тест проходит
- [x] Jetson AGX Orin: база (нативно + QEMU) + FAST-LIO2, опубликованы, тест проходит
- [x] Jetson Orin Nano (JP7/Jazzy): база + FAST-LIO2, опубликованы
- [x] Универсальный шаблон пакета работает на Humble и Jazzy (x86, ARM)
- [x] CI/CD: матрица (3 платформы), два способа ARM, кеширование, тесты образов, триггеры (push/тег/ручной)
- [x] Документация, smoke-тест
- [ ] (улучшение) когда выйдет официальный l4t под JP7 (r38) — заменить FROM у Orin Nano
- [ ] (улучшение) перевести базовые Dockerfile x86/AGX на общий `scripts/install_ros2.sh` (как у Nano)