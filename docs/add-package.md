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

## Добавить новую платформу (на примере Orin Nano, JP7)
Двухслойная архитектура рассчитана на это. По шагам:

1. **Базовый Dockerfile** `docker/base/jetson-nano/Dockerfile`:
   - `FROM` подходящего l4t-образа под JP7 (Ubuntu 24.04);
   - установка ROS2 **Jazzy** (не Humble — JP7 на Ubuntu 24.04). Логика установки уже параметризована
     в `scripts/install_ros2.sh` — достаточно вызвать её с `jazzy`.

2. **Матрицы в `build.yml`** — добавить ячейку в `build-base` и в `build-package`:
   ```yaml
   - name: jetson-nano (native ARM64)
     context: docker/base/jetson-nano
     arch: linux/arm64
     runner: ubuntu-24.04-arm
     tags: ghcr.io/ilyasalih/ros2-cuda-jetson-nano:jazzy-l4t-jp7
     cache_scope: base-jetson-nano
   ```
   и аналогичную ячейку пакета с `BASE_IMAGE` = эта база, `CUDA_ARCHITECTURES=87`.

3. **Собрать пакет под Jazzy.** Тут единственная реальная неопределённость: FAST-LIO2 (`Taeyoung96/FAST_LIO_ROS2`,
   ветка `ros2`) заточен под Humble; на Jazzy может потребоваться другая ветка/форк или мелкие правки.
   Именно поэтому Orin Nano вынесен как **опциональный** — база добавляется тривиально, а совместимость
   пакета с Jazzy требует проверки.

Всё остальное (кеш, тесты, публикация, два способа сборки) платформа наследует от матрицы автоматически.