# Добавление нового ROS2-пакета и новой платформы

## Добавить новый ROS2-пакет
Сборочный слой `docker/package/Dockerfile` параметризован — пакет меняется аргументами, без правки Dockerfile.

| ARG | Назначение | Пример |
|-----|-----------|--------|
| `BASE_IMAGE` | базовый образ (ROS2 + CUDA нужной платформы) | `ghcr.io/ilyasalih/ros2-cuda-x86:humble-cuda12.6` |
| `FASTLIO_REPO` | git-репозиторий пакета | `https://github.com/Taeyoung96/FAST_LIO_ROS2.git` |
| `FASTLIO_BRANCH` | ветка | `ros2` |
| `CUDA_ARCHITECTURES` | CUDA compute capability цели | `89` (x86) / `87` (Orin) |

```bash
docker build \
  --build-arg BASE_IMAGE=ghcr.io/ilyasalih/ros2-cuda-x86:humble-cuda12.6 \
  --build-arg FASTLIO_REPO=https://github.com/<owner>/<repo>.git \
  --build-arg FASTLIO_BRANCH=<branch> \
  --build-arg CUDA_ARCHITECTURES=89 \
  -t ghcr.io/<user>/<pkg>-x86:humble-cuda12.6 docker/package/
```
Проверка: `bash tests/test_image.sh <образ>`.

**Замечание.** Текущий шаблон заточен под цепочку зависимостей FAST-LIO (Livox-SDK2 + livox_ros_driver2).
Для пакета без этих зависимостей соответствующие шаги можно убрать/сделать опциональными. Направление
развития — манифест `packages/<name>.yaml` (repo, branch, cuda-arch), который CI перебирает матрицей.

## Добавить новую платформу
Двухслойная архитектура рассчитана на это. По шагам (на примере уже реализованного **Orin Nano**):

1. **Базовый Dockerfile** `docker/base/<platform>/Dockerfile`:
   - `FROM` подходящего образа с CUDA (для Orin Nano — `nvidia/cuda:13.x-devel-ubuntu24.04`, т.к.
     официального l4t под JP7 ещё нет);
   - установка ROS2 нужного дистрибутива через общий скрипт: `RUN bash /tmp/install_ros2.sh <distro>`
     (`humble` для Ubuntu 22.04, `jazzy` для Ubuntu 24.04). Скрипт копируется из `scripts/`, поэтому
     build-контекст этой платформы = корень репо (см. поля `context`/`file` в матрице).

2. **Матрицы в `build.yml`** — добавить ячейку в `build-base` и в `build-package`:
   ```yaml
   # base:
   - name: <platform> (native ARM64)
     context: .
     file: docker/base/<platform>/Dockerfile
     arch: linux/arm64
     runner: ubuntu-24.04-arm
     tags: ghcr.io/<user>/ros2-cuda-<platform>:<tag>
     cache_scope: base-<platform>
   # package: своя ячейка с BASE_IMAGE = эта база, CUDA_ARCHITECTURES=87
   ```

3. **Особенности дистрибутива при сборке пакета.** Если платформа на другом ROS2 (например, Jazzy на
   Ubuntu 24.04), Humble-пакеты могут не собраться из-за требований к стандарту C++. Так было с FAST-LIO2
   на Orin Nano/Jazzy: rclcpp требует C++17, а FAST-LIO жёстко ставит C++14 — в `docker/package/Dockerfile`
   добавлен патч, заменяющий C++14 → C++17 в его `CMakeLists.txt` перед сборкой. Путь к setup-скрипту ROS2
   тоже параметризован (`/opt/ros/${ROS_DISTRO}/setup.sh`).

Всё остальное (кеш, тесты, публикация, два способа сборки) платформа наследует от матрицы автоматически.