// Минимальный CUDA-сэмпл для smoke-теста образа.
// Если nvcc его СКОМПИЛИРОВАЛ — CUDA-тулчейн в образе рабочий (GPU не нужен).
// Если GPU доступен (не в VirtualBox) — реально сложит два вектора на устройстве.
#include <cstdio>
#include <cstdlib>
#include <cuda_runtime.h>

__global__ void vecAdd(const float* a, const float* b, float* c, int n) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i < n) c[i] = a[i] + b[i];
}

int main() {
    int devices = 0;
    cudaError_t err = cudaGetDeviceCount(&devices);
    if (err != cudaSuccess || devices == 0) {
        printf("GPU не найден (%s). Это ОЖИДАЕМО в VM без проброса GPU.\n",
               cudaGetErrorString(err));
        printf("Главное: nvcc успешно скомпилировал .cu -> CUDA-тулчейн рабочий.\n");
        return 0;               // компиляция прошла = smoke-тест пройден
    }

    const int n = 1 << 20;
    const size_t bytes = n * sizeof(float);
    float *ha = (float*)malloc(bytes), *hb = (float*)malloc(bytes), *hc = (float*)malloc(bytes);
    for (int i = 0; i < n; ++i) { ha[i] = 1.0f; hb[i] = 2.0f; }

    float *da, *db, *dc;
    cudaMalloc(&da, bytes); cudaMalloc(&db, bytes); cudaMalloc(&dc, bytes);
    cudaMemcpy(da, ha, bytes, cudaMemcpyHostToDevice);
    cudaMemcpy(db, hb, bytes, cudaMemcpyHostToDevice);

    int threads = 256, blocks = (n + threads - 1) / threads;
    vecAdd<<<blocks, threads>>>(da, db, dc, n);
    cudaDeviceSynchronize();
    cudaMemcpy(hc, dc, bytes, cudaMemcpyDeviceToHost);

    bool ok = true;
    for (int i = 0; i < n; ++i) if (hc[i] != 3.0f) { ok = false; break; }
    printf("Vector add на GPU (%d устройств): %s\n", devices, ok ? "РЕЗУЛЬТАТ ВЕРНЫЙ" : "ОШИБКА");

    cudaFree(da); cudaFree(db); cudaFree(dc);
    free(ha); free(hb); free(hc);
    return ok ? 0 : 1;
}
