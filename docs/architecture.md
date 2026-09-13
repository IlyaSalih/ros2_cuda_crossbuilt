# Архитектура системы сборки

## Цель
Кросс-платформенная сборка Docker-образов для ROS2-пакетов с поддержкой CUDA
под несколько платформ, с публикацией в реестр и автоматизацией через CI/CD.

## Целевые платформы
| Платформа | CPU | GPU (compute cap.) | Базовый образ | ROS2 |
|-----------|-----|--------------------|---------------|------|
| x86_64 + NVIDIA dGPU | x86_64 | зависит от карты (RTX 4060 = sm_89) | `nvidia/cuda:12.6.2-devel-ubuntu22.04` | Humble |
| Jetson AGX Orin (JP 6.2.2 / L4T R36.5) | ARM64 | Ampere sm_87 | `nvcr.io/nvidia/l4t-jetpack:r36.4.0` | Humble |
| Jetson Orin Nano (JP 7) | ARM64 | Ampere sm_87 | l4t под JP7 (Ubuntu 24.04) | Jazzy (опционально) |

Ключевые различия:
- **x86** использует настольные образы `nvidia/cuda`; **Jetson** — L4T-образы NVIDIA
  (`nvcr.io/nvidia/l4t-*`), привязанные к версии JetPack.
- Для JP 6.2.2 тега `l4t-jetpack:r36.5.0` нет; используется `r36.4.0` (совместим, содержит CUDA/cuDNN/TensorRT).
- **CUDA-архитектура** (`sm_*`) различается и передаётся в сборку аргументом `CUDA_ARCHITECTURES` (x86 = 89, Orin = 87).
- **Дистрибутив ROS2** зависит от Ubuntu базы: 22.04 → Humble (x86, AGX Orin), 24.04 → Jazzy (Orin Nano JP7).

## Стратегия сборки (двухслойная)
1. **Базовые образы** (`docker/base/<platform>/`) — ROS2 + CUDA Toolkit + системные зависимости.
   Собираются и публикуются отдельно. Логика установки ROS2 вынесена в `scripts/install_ros2.sh`
   (параметризована дистрибутивом) — единый источник правды.
2. **Слой пакета** (`docker/package/`) — **один универсальный Dockerfile**, собирает ROS2-пакет
   ПОВЕРХ выбранной базы. Аргументы: `BASE_IMAGE`, `FASTLIO_REPO`, `FASTLIO_BRANCH`, `CUDA_ARCHITECTURES`.
   Один и тот же шаблон собирает пакет и на x86, и на ARM — меняются только аргументы.

## Кросс-компиляция ARM64 (два способа, требование 3.4)
- **Нативно** на ARM64-раннере GitHub (`runs-on: ubuntu-24.04-arm`) — без эмуляции, быстро (~5 мин базы).
- **Кросс** на x86 через `docker buildx` + QEMU (`setup-qemu-action`, `platforms: linux/arm64`) — портируемо,
  но медленно из-за эмуляции (~30 мин базы). Тяжёлые сборки (компиляция C++ пакета) — только нативно.

## CUDA и её подтверждение
FAST-LIO2 сам по себе CPU-only, но образы содержат полный CUDA-стек. Подтверждение — на уровне сборки:
`nvcc --version`, наличие библиотек в `/usr/local/cuda/lib64` и компиляция тестового `.cu`
(`tests/cuda-smoke/vector_add.cu`). Рантайм на GPU требует хоста с видеокартой и `nvidia-container-toolkit`.

## CI/CD (GitHub Actions)
Единый пайплайн `.github/workflows/build.yml`:
- **Триггеры:** push в `main`/`master`, тег `v*`, ручной запуск.
- **Джобы:**
  - `build-base` — матрица нативных баз (x86, Jetson AGX) → канонические теги.
  - `build-base-cross-qemu` — Jetson-база через QEMU (второй способ), независимо.
  - `build-package` — матрица пакетов (x86, Jetson) `needs: build-base`, + шаг **теста образа** на своей арке.
- **Кеширование** слоёв через `type=gha` (раздельные scope на ячейку).
- **Публикация** в ghcr.io через встроенный `GITHUB_TOKEN`.

Порядок `build-base → build-package` обязателен: пакет собирается `FROM <база>`, база должна уже быть в реестре.

## Как добавить платформу (на примере Orin Nano)
Архитектура рассчитана на расширение. Добавление Orin Nano (JP7):
1. Базовый Dockerfile `docker/base/jetson-nano/` — `FROM` l4t под JP7, установка ROS2 **Jazzy**
   (`install_ros2.sh jazzy`, т.к. JP7 = Ubuntu 24.04).
2. В `build.yml` — добавить ячейку в матрицы `build-base` и `build-package` (арх `linux/arm64`,
   `CUDA_ARCHITECTURES=87`, свои теги).
3. Проверить, что FAST-LIO2 собирается под Jazzy (может потребоваться правка ветки/патч — это и есть
   причина, почему Orin Nano опционален и вынесен отдельно).

## Текущий статус
- [x] x86: база + FAST-LIO2, опубликованы, тест проходит
- [x] Jetson AGX Orin: база (нативно + QEMU) + FAST-LIO2, опубликованы, тест проходит
- [x] Универсальный шаблон пакета работает на x86 и ARM
- [x] CI/CD: матрица, два способа ARM, кеширование, тесты образов, триггеры (push/тег/ручной)
- [x] Документация, smoke-тест
- [ ] Jetson Orin Nano (JP7) — опционально
- [ ] (улучшение) перевод базовых Dockerfile на общий `scripts/install_ros2.sh` (требует контекст = корень репо)