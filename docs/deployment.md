# Развёртывание пайплайна

Сборка, публикация и проверка образов проекта — кросс-платформенная сборка
ROS2-пакетов с поддержкой CUDA.

## Требования
- Docker Engine (для ARM/Jetson-сборки также `docker buildx`, см. `architecture.md`)
- git
- Аккаунт GitHub с доступом к GitHub Container Registry (ghcr.io)
- GPU + `nvidia-container-toolkit` — **опционально**, только для запуска CUDA на x86.
  Для СБОРКИ и подтверждения наличия CUDA видеокарта не нужна.

## Структура репозитория
```
docker/base/{x86,jetson-agx,jetson-nano}/Dockerfile  — базовые образы (ROS2 + CUDA)
docker/package/Dockerfile                            — универсальный слой сборки пакета
scripts/fetch_sources.sh                             — запасная загрузка исходников (слабая сеть)
tests/{test_image.sh, cuda-smoke/}                   — smoke-тест образа
.github/workflows/build.yml                          — CI
docs/                                                — документация
```

## Сборка локально (x86)
```bash
# 1. Базовый образ: ROS2 Humble + CUDA
docker build -t ghcr.io/ilyasalih/ros2-cuda-x86:humble-cuda12.6 docker/base/x86/

# 2. Пакет FAST-LIO2 поверх базы
docker build -t ghcr.io/ilyasalih/fast-lio2-x86:humble-cuda12.6 docker/package/
```

## Использование готовых образов из реестра
Образы опубликованы в ghcr.io (публично):
```bash
docker pull ghcr.io/ilyasalih/ros2-cuda-x86:humble-cuda12.6
docker pull ghcr.io/ilyasalih/fast-lio2-x86:humble-cuda12.6
```

## Публикация в реестр
```bash
echo <PAT c write:packages> | docker login ghcr.io -u <user> --password-stdin
docker push ghcr.io/ilyasalih/ros2-cuda-x86:humble-cuda12.6
docker push ghcr.io/ilyasalih/fast-lio2-x86:humble-cuda12.6
```
После первого пуша: сделать пакет публичным и привязать к репозиторию
(GitHub → Packages → Package settings).

## Проверка образа (CUDA + ROS2)
```bash
bash tests/test_image.sh ghcr.io/ilyasalih/fast-lio2-x86:humble-cuda12.6
```
Проверяет: наличие `nvcc`, компиляцию CUDA-сэмпла, `libcudart`, сборку ROS2-пакетов.

## CI (GitHub Actions)
`.github/workflows/build.yml` запускается при push в main/master и вручную
(workflow_dispatch): собирает базу и пакет, пушит в ghcr через встроенный
`GITHUB_TOKEN` (не требует PAT).