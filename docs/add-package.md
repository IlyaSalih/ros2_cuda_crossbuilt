# Добавление нового ROS2-пакета

Сборочный слой `docker/package/Dockerfile` параметризован, чтобы добавлять
пакеты с минимальными изменениями.

## Аргументы шаблона
| ARG | Назначение | По умолчанию |
|-----|-----------|--------------|
| `BASE_IMAGE` | базовый образ (ROS2 + CUDA нужной платформы) | `ros2-cuda-x86:humble-cuda12.6` |
| `FASTLIO_REPO` | git-репозиторий пакета | `Taeyoung96/FAST_LIO_ROS2` |
| `FASTLIO_BRANCH` | ветка | `ros2` |
| `CUDA_ARCHITECTURES` | CUDA compute capability цели (x86 = 89, Orin = 87) | `89` |

## Через build-arg (быстрый способ)
```bash
docker build \
  --build-arg FASTLIO_REPO=https://github.com/<owner>/<repo>.git \
  --build-arg FASTLIO_BRANCH=<branch> \
  --build-arg CUDA_ARCHITECTURES=87 \
  -t ghcr.io/<user>/<pkg>-x86:humble-cuda12.6 docker/package/
```

## Замечания
- Текущий шаблон заточен под цепочку зависимостей FAST-LIO
  (Livox-SDK2 + livox_ros_driver2). Для пакета без этих зависимостей
  соответствующие шаги можно убрать или сделать опциональными.
- Направление развития — манифест `packages/<name>.yaml`
  (repo, branch, cuda-arch, доп. зависимости), который CI перебирает матрицей.
  Тогда добавление пакета = один yaml-файл, без правки Dockerfile.

## Проверка нового образа
```bash
bash tests/test_image.sh ghcr.io/<user>/<pkg>-x86:humble-cuda12.6
```