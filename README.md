# ros2-cuda-crossbuild

Система автоматической **кросс-платформенной сборки Docker-образов** для ROS2-пакетов
с поддержкой **CUDA**, с публикацией в реестр и CI/CD.

Тестовый пакет — [FAST-LIO2](https://github.com/Taeyoung96/FAST_LIO_ROS2) (LiDAR-инерциальная одометрия).

## Что умеет
- Собирает **базовые образы** (ROS2 Humble + CUDA) под несколько платформ.
- Собирает ROS2-пакет **одним универсальным шаблоном** поверх любой базы (меняются только аргументы).
- Два способа сборки ARM64: **нативно на ARM-раннере** и **кросс через QEMU** на x86.
- CI/CD в GitHub Actions: **матрица платформ**, кеширование слоёв, тестирование образов, публикация в ghcr.io.
- Подтверждение CUDA в образах (компиляция `.cu`) — см. `tests/`.

## Платформы
| Платформа | Арх. | CUDA (sm_) | База | ROS2 | Статус |
|-----------|------|------------|------|------|--------|
| x86_64 + NVIDIA dGPU | amd64 | 89 (пример: RTX 4060) | `nvidia/cuda:12.6.2-devel-ubuntu22.04` | Humble | ✅ |
| Jetson AGX Orin (JP 6.2.2) | arm64 | 87 | `nvcr.io/nvidia/l4t-jetpack:r36.4.0` | Humble | ✅ |
| Jetson Orin Nano (JP 7) | arm64 | 87 | l4t (JP7, Ubuntu 24.04) | Jazzy | ⬜ опционально |

## Опубликованные образы (ghcr.io)
- `ghcr.io/ilyasalih/ros2-cuda-x86:humble-cuda12.6` — база x86
- `ghcr.io/ilyasalih/ros2-cuda-jetson-agx:humble-l4t-r36.4` — база Jetson AGX (нативно)
- `ghcr.io/ilyasalih/ros2-cuda-jetson-agx:humble-l4t-r36.4-qemu` — база Jetson AGX (кросс QEMU)
- `ghcr.io/ilyasalih/fast-lio2-x86:humble-cuda12.6` — FAST-LIO2 на x86
- `ghcr.io/ilyasalih/fast-lio2-jetson-agx:humble-l4t-r36.4` — FAST-LIO2 на Jetson AGX

## Быстрый старт
```bash
# собрать локально (x86): база + пакет + тест
bash scripts/build_local.sh x86

# проверить готовый образ
bash tests/test_image.sh ghcr.io/ilyasalih/fast-lio2-x86:humble-cuda12.6
```

## Документация
- [docs/deployment.md](docs/deployment.md) — как собрать, опубликовать и проверить образы; CI.
- [docs/architecture.md](docs/architecture.md) — платформы, стратегия сборки, кросс-компиляция, CUDA, схема CI.
- [docs/add-package.md](docs/add-package.md) — как добавить новый ROS2-пакет и **как добавить платформу (на примере Orin Nano)**.

## Структура репозитория
```
docker/base/{x86,jetson-agx,jetson-nano}/  — базовые образы (ROS2 + CUDA)
docker/package/                            — универсальный шаблон сборки пакета
scripts/                                   — install_ros2.sh, build_local.sh, check_cuda.sh, fetch_sources.sh
tests/                                     — smoke-тест образа (CUDA + ROS2)
.github/workflows/build.yml                — CI/CD (матрица)
docs/                                      — документация
```