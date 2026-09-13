# syntax=docker/dockerfile:1
#
# Сборочный слой: ROS2-пакет (FAST-LIO2) поверх базового образа.
#
# ВАЖНО: ROS2-код FAST-LIO живёт на ветке `ros2` (main форков = исходный ROS1!).
# Репозиторий на ветке ros2 = workspace-src: FAST_LIO/ (ament) + livox_ros_driver2
# (сабмодуль) + ikd-Tree (сабмодуль внутри FAST_LIO). Тянем с --recursive.
# Цепочка: Livox-SDK2 -> livox_ros_driver2 + FAST_LIO -> colcon build.

ARG BASE_IMAGE=ghcr.io/ilyasalih/ros2-cuda-x86:humble-cuda12.6
FROM ${BASE_IMAGE}

# --- Аргументы шаблона (п.3.3: repo, ветка, CUDA-архитектура) ---
ARG FASTLIO_REPO=https://github.com/Taeyoung96/FAST_LIO_ROS2.git
ARG FASTLIO_BRANCH=ros2
# x86/RTX 4060 = 89, Orin = 87. FAST-LIO CUDA не использует (CPU-only),
# аргумент — для универсальности шаблона под CUDA-пакеты.
ARG CUDA_ARCHITECTURES=89

# --- git: HTTP/1.1 + большой буфер (устойчивость клонов) ---
ENV GIT_HTTP_LOW_SPEED_LIMIT=1000 \
    GIT_HTTP_LOW_SPEED_TIME=60
RUN git config --global http.version HTTP/1.1 \
 && git config --global http.postBuffer 524288000

# --- 1. Livox-SDK2 (системная зависимость livox_ros_driver2) ---
RUN for i in $(seq 1 5); do \
        git clone https://github.com/Livox-SDK/Livox-SDK2.git /tmp/Livox-SDK2 && break ; \
        echo "retry Livox-SDK2 clone ($i)" ; sleep 10 ; rm -rf /tmp/Livox-SDK2 ; \
    done \
 && cd /tmp/Livox-SDK2 && mkdir build && cd build \
 && cmake .. && make -j"$(nproc)" && make install && ldconfig \
 && rm -rf /tmp/Livox-SDK2

# --- 2. ROS2-порт FAST-LIO с сабмодулями (ветка ros2!) ---
WORKDIR /root/ros2_ws
RUN mkdir -p src \
 && for i in $(seq 1 5); do \
        git clone --recursive -b "${FASTLIO_BRANCH}" "${FASTLIO_REPO}" src/fast_lio_ros2 && break ; \
        echo "retry FAST_LIO_ROS2 clone ($i)" ; sleep 10 ; rm -rf src/fast_lio_ros2 ; \
    done \
 && [ -d src/fast_lio_ros2/livox_ros_driver2 ] \
 # Подготовка livox_ros_driver2 под Humble (то, что делает build.sh humble):
 && cd src/fast_lio_ros2/livox_ros_driver2 \
 && cp -f package_ROS2.xml package.xml \
 && cp -rf launch_ROS2/ launch/

# --- Патч для Jazzy: FAST_LIO жёстко ставит C++14, а rclcpp в Jazzy требует C++17 ---
RUN sed -i 's/CMAKE_CXX_STANDARD 14/CMAKE_CXX_STANDARD 17/g; s/c++14/c++17/g' \
        src/fast_lio_ros2/FAST_LIO/CMakeLists.txt

# --- 3. Сборка через colcon (с флагами livox для Humble) ---
RUN . /opt/ros/${ROS_DISTRO}/setup.sh \
 && colcon build --symlink-install \
      --cmake-args -DCMAKE_BUILD_TYPE=Release -DCMAKE_CXX_STANDARD=17 \
                   -DROS_EDITION=ROS2 -DHUMBLE_ROS=humble \
                   -DCMAKE_CUDA_ARCHITECTURES="${CUDA_ARCHITECTURES}"

# --- Автосорс workspace ---
RUN echo "source /root/ros2_ws/install/setup.bash" >> /etc/bash.bashrc

CMD ["bash"]