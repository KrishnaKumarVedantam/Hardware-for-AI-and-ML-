#include <stdio.h>
#include <stdlib.h>
#include <cuda_runtime.h>

#define N 1024

__global__ void gemm_naive_kernel(const float* A, const float* B, float* C, int n) {
    int row = blockIdx.y * blockDim.y + threadIdx.y;
    int col = blockIdx.x * blockDim.x + threadIdx.x;
    if (row < n && col < n) {
        float sum = 0.0f;
        for (int k = 0; k < n; k++)
            sum += A[row * n + k] * B[k * n + col];
        C[row * n + col] = sum;
    }
}

void fill_random(float* mat, int n) {
    for (int i = 0; i < n * n; i++)
        mat[i] = (float)rand() / RAND_MAX;
}

int main() {
    printf("=== Naive GEMM: %dx%d FP32 ===\n", N, N);
    size_t bytes = (size_t)N * N * sizeof(float);
    float *h_A=(float*)malloc(bytes), *h_B=(float*)malloc(bytes), *h_C=(float*)malloc(bytes);
    srand(42); fill_random(h_A, N); fill_random(h_B, N);
    float *d_A, *d_B, *d_C;
    cudaMalloc(&d_A, bytes); cudaMalloc(&d_B, bytes); cudaMalloc(&d_C, bytes);
    cudaMemcpy(d_A, h_A, bytes, cudaMemcpyHostToDevice);
    cudaMemcpy(d_B, h_B, bytes, cudaMemcpyHostToDevice);
    dim3 blockDim(16, 16);
    dim3 gridDim((N+15)/16, (N+15)/16);
    // Warm-up
    gemm_naive_kernel<<<gridDim, blockDim>>>(d_A, d_B, d_C, N);
    cudaDeviceSynchronize();
    // Timed run
    cudaEvent_t start, stop;
    cudaEventCreate(&start); cudaEventCreate(&stop);
    cudaEventRecord(start);
    gemm_naive_kernel<<<gridDim, blockDim>>>(d_A, d_B, d_C, N);
    cudaEventRecord(stop); cudaEventSynchronize(stop);
    float ms = 0.0f;
    cudaEventElapsedTime(&ms, start, stop);
    double gflops = (2.0*N*N*N) / (ms*1e-3) / 1e9;
    printf("Execution time : %.4f ms\n", ms);
    printf("Achieved GFLOP/s: %.2f\n", gflops);
    cudaFree(d_A); cudaFree(d_B); cudaFree(d_C);
    free(h_A); free(h_B); free(h_C);
    return 0;
}
