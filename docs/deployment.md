# Развёртывание пайплайна

Сборка, публикация и проверка образов проекта.

## Требования
- Docker Engine; для ARM/Jetson-сборки — `docker buildx` (+ QEMU для кросс-сборки на x86).
- git; аккаунт GitHub с доступом к ghcr.io.
- GPU + `nvidia-container-toolkit` — **опционально**, только для запуска CUDA на x86.
  Для сборки и подтверждения наличия CUDA видеокарта не нужна.

## Сборка локально
Одной командой (база + пакет + smoke-тест):
```bash
bash scripts/build_local.sh x86          # x86
bash scripts/build_local.sh jetson-agx   # Jetson (ARM: локально через QEMU — медленно, лучше в CI)
```
Или вручную:
```bash
# база
docker build -t ghcr.io/ilyasalih/ros2-cuda-x86:humble-cuda12.6 docker/base/x86/
# пакет поверх базы
docker build \
  --build-arg BASE_IMAGE=ghcr.io/ilyasalih/ros2-cuda-x86:humble-cuda12.6 \
  --build-arg CUDA_ARCHITECTURES=89 \
  -t ghcr.io/ilyasalih/fast-lio2-x86:humble-cuda12.6 docker/package/
```

## Использование готовых образов
```bash
docker pull ghcr.io/ilyasalih/fast-lio2-x86:humble-cuda12.6
docker pull ghcr.io/ilyasalih/fast-lio2-jetson-agx:humble-l4t-r36.4
```

## Публикация в реестр
```bash
echo <PAT c write:packages> | docker login ghcr.io -u <user> --password-stdin
docker push ghcr.io/ilyasalih/ros2-cuda-x86:humble-cuda12.6
```
После первого пуша — сделать пакет публичным и привязать к репозиторию (GitHub → Packages → Package settings).
Если пуш из CI падает с `denied: permission_denied` для уже существующего пакета —
Package settings → **Manage Actions access** → добавить репозиторий с ролью **Write**.

## Проверка образа (CUDA + ROS2)
```bash
bash tests/test_image.sh ghcr.io/ilyasalih/fast-lio2-x86:humble-cuda12.6
# только CUDA:
bash scripts/check_cuda.sh ghcr.io/ilyasalih/fast-lio2-x86:humble-cuda12.6
```

## CI/CD
Единый workflow `.github/workflows/build.yml`. Запускается на push в `main`/`master`, на тег `v*`
и вручную (Actions → Build & push (matrix) → Run workflow). Собирает базы и пакеты по матрице,
тестирует образы, публикует в ghcr.io. Подробности архитектуры — в `architecture.md`.

Ручной запуск ARM/Jetson-сборки: там же во вкладке Actions. Нативные ARM-раннеры бесплатны для публичных репозиториев.

## Сеть при сборке (заметки)
Если git clone внутри сборки виснет/рвётся (частая проблема в VM/за VPN): помогает форс IPv4,
HTTP/1.1 и таймауты (заложены в Dockerfile'ах). Как альтернатива — `scripts/fetch_sources.sh`
загружает исходники тарболами (curl), после чего Dockerfile можно перевести на `COPY` вместо `git clone`.