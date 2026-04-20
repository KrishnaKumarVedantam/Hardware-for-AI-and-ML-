#include <stdio.h>
#include <stdlib.h>
#include <cuda_runtime.h>

#define N    1024
#define TILE 8

__global__ void gemm_tiled_kernel(const float* A, const float* B, float* C, int n) {
    __shared__ float sA[TILE][TILE];
    __shared__ float sB[TILE][TILE];
    int row = blockIdx.y * TILE + threadIdx.y;
    int col = blockIdx.x * TILE + threadIdx.x;
    float sum = 0.0f;
    int numTiles = (n + TILE - 1) / TILE;
    for (int t = 0; t < numTiles; t++) {
        int aCol = t * TILE + threadIdx.x;
        sA[threadIdx.y][threadIdx.x] = (row < n && aCol < n) ? A[row * n + aCol] : 0.0f;
        int bRow = t * TILE + threadIdx.y;
        sB[threadIdx.y][threadIdx.x] = (bRow < n && col < n) ? B[bRow * n + col] : 0.0f;
        __syncthreads();
        for (int k = 0; k < TILE; k++)
            sum += sA[threadIdx.y][k] * sB[k][threadIdx.x];
        __syncthreads();
    }
    if (row < n && col < n)
        C[row * n + col] = sum;
}

void fill_random(float* mat, int n) {
    for (int i = 0; i < n * n; i++)
        mat[i] = (float)rand() / RAND_MAX;
}

int main() {
    printf("=== Tiled GEMM (TILE=8): %dx%d FP32 ===\n", N, N);
    size_t bytes = (size_t)N * N * sizeof(float);
    float *h_A=(float*)malloc(bytes), *h_B=(float*)malloc(bytes), *h_C=(float*)malloc(bytes);
    srand(42); fill_random(h_A, N); fill_random(h_B, N);
    float *d_A, *d_B, *d_C;
    cudaMalloc(&d_A, bytes); cudaMalloc(&d_B, bytes); cudaMalloc(&d_C, bytes);
    cudaMemcpy(d_A, h_A, bytes, cudaMemcpyHostToDevice);
    cudaMemcpy(d_B, h_B, bytes, cudaMemcpyHostToDevice);
    dim3 blockDim(TILE, TILE);
    dim3 gridDim((N+TILE-1)/TILE, (N+TILE-1)/TILE);
    // Warm-up
    gemm_tiled_kernel<<<gridDim, blockDim>>>(d_A, d_B, d_C, N);
    cudaDeviceSynchronize();
    // Timed run
    cudaEvent_t start, stop;
    cudaEventCreate(&start); cudaEventCreate(&stop);
    cudaEventRecord(start);
    gemm_tiled_kernel<<<gridDim, blockDim>>>(d_A, d_B, d_C, N);
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
