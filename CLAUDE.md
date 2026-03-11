# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What is libintx

libintx is a C++ library for computing molecular integrals over Gaussian atomic orbitals using the McMurchie-Davidson (MD) recurrence scheme. It supports CPU (with optional SIMD) and GPU (CUDA/HIP) backends.

## Build Commands

```bash
# CPU-only build
cmake -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build -j$(nproc)

# CUDA GPU build (set architectures as needed)
cmake -B build -DLIBINTX_CUDA=ON -DCMAKE_CUDA_ARCHITECTURES="native" -DCMAKE_BUILD_TYPE=Release
cmake --build build -j$(nproc)

# HIP GPU build
cmake -B build -DLIBINTX_HIP=ON -DCMAKE_BUILD_TYPE=Release
cmake --build build -j$(nproc)
```

### Key CMake Options

- `LIBINTX_CUDA=ON` — Enable CUDA backend
- `LIBINTX_HIP=ON` — Enable HIP/ROCm backend
- `CMAKE_CUDA_ARCHITECTURES` — Target GPU SM versions (e.g. `"70;80;89;90;120"` or `"native"`)
- `LIBINTX_MAX_L` — Max angular momentum L (default: 4, i.e. up to g-functions)
- `LIBINTX_MAX_X` — Max auxiliary basis L for 3-center integrals (default: 6)
- `LIBINTX_SIMD=OFF` — Disable experimental SIMD support

### Dependencies

- CMake 3.18+, C++20 compiler
- Eigen (header-only, bundled in `include/`)
- BLAS/LAPACK (libopenblas-dev + liblapacke-dev on Ubuntu)
- CUDA toolkit (for GPU builds)

## Running Tests

```bash
# All tests
cd build && ctest

# GPU tests only
ctest -R gpu

# Specific test binary
./build/tests/boys.gpu.test
./build/tests/libintx.gpu.md3.test
./build/tests/libintx.gpu.md4.test

# Performance benchmarks
./build/tests/libintx.gpu.md3.perf [L_bra] [L_ket_C] [L_ket_D]
./build/tests/libintx.gpu.md4.perf [L_bra_A] [L_bra_B] [L_ket_C] [L_ket_D]
```

Test framework is **doctest** (bundled in `tests/doctest.h`). GPU tests may be slow due to CPU reference computation, not GPU execution.

## Architecture

### IntegralEngine Hierarchy

```
libintx::ao::IntegralEngine<N>          (src/libintx/ao/engine.h)  — abstract base
  └─ libintx::gpu::IntegralEngine<N>    (src/libintx/gpu/engine.h) — GPU virtual interface
       └─ libintx::gpu::md::IntegralEngine<N> (src/libintx/gpu/md/engine.h) — MD GPU implementation
```

N=3 is 3-center integrals (bra=Index1, ket=Index2), N=4 is 4-center (both Index2).

### Key Source Layout

- `src/libintx/` — Core headers: `orbital.h`, `shell.h`, `forward.h`, `math.h`, `array.h`
- `src/libintx/ao/` — Abstract integral engine, MD recurrence (`hermite.h`)
- `src/libintx/gpu/` — GPU backend entry point and engine
- `src/libintx/gpu/md/` — GPU MD kernels: `md.kernel.h` (shared), `md3.kernel.h` (3-center), `md4.kernel.h` (4-center)
- `include/` — Bundled Eigen, CUTLASS, and other header-only dependencies
- `tests/` — doctest-based tests and performance benchmarks

### Kernel Compilation Strategy

GPU kernels are instantiated per angular-momentum pair (BRA, KET). CMake generates separate object libraries for each combination using `libintx_gpu_kernel()` macros in `src/libintx/gpu/md/CMakeLists.txt`. This is necessary because each instantiation is expensive to compile.

### Hermite Recurrence API

`hermite_to_cartesian` and `hermite_to_pure` in `src/libintx/ao/md/hermite.h` use `std::integral_constant` indices rather than `Orbital` objects. Callbacks receive integral constants (e.g., `auto px, auto py, auto pz`) not orbital structs.

## NVCC/CUDA Gotchas

- NVCC struggles with some C++20 features: template argument deduction across mixed `integral_constant` types may need explicit `int()` casts
- GCC's experimental SIMD headers (`<experimental/simd>`) are incompatible with NVCC — guard with `#if !defined(__CUDACC__)`
- The `tests/test.h` header is shared between CPU and GPU tests; SIMD includes are conditionally compiled

## Apptainer Container

`libintx.def` defines an Apptainer/Singularity container for portable GPU benchmarking:

```bash
apptainer build libintx.sif libintx.def
apptainer run --nv libintx.sif libintx.gpu.md3.perf 2 3 3
```
