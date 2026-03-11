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
- `CMAKE_CUDA_ARCHITECTURES` — Target GPU SM versions (e.g. `"80;89;90;100;120"` or `"native"`)
- `LIBINTX_MAX_L` — Max angular momentum L (default: 4, i.e. up to g-functions)
- `LIBINTX_MAX_X` — Max auxiliary basis L for 3-center integrals (default: 6)
- `LIBINTX_SIMD=OFF` — Disable experimental SIMD support

### Dependencies

- CMake 3.18+, C++20 compiler
- Eigen (header-only, bundled in `include/`)
- BLAS/LAPACK (libopenblas-dev + liblapacke-dev on Ubuntu)
- CUDA toolkit (for GPU builds)

## Running Tests and Benchmarks

Test framework is **doctest** (bundled in `tests/doctest.h`). GPU tests may be slow due to CPU reference computation, not GPU execution.

```bash
# All tests via ctest
cd build && ctest

# GPU tests only
ctest -R gpu

# CPU tests only
ctest -R md[234].test
```

### CPU Tests

```bash
./build/tests/pure.test              # Pure spherical harmonic transforms
./build/tests/boys.test              # Boys function evaluation
./build/tests/libintx.md.test        # MD recurrence core tests
./build/tests/libintx.md2.test       # 2-center integral tests
./build/tests/libintx.md3.test       # 3-center integral tests
./build/tests/libintx.md4.test       # 4-center integral tests
```

### GPU Tests

```bash
./build/tests/boys.gpu.test          # Boys function on GPU
./build/tests/libintx.gpu.md3.test   # 3-center integrals on GPU
./build/tests/libintx.gpu.md4.test   # 4-center integrals on GPU
./build/tests/libintx.gpu.jengine.test  # J-engine (multi-GPU Coulomb engine)
```

### CPU Benchmarks

```bash
./build/tests/libintx.md2.perf [Nbra] [Nket]   # 2-center benchmark
./build/tests/libintx.md3.perf [Nbra] [Nket]   # 3-center benchmark
./build/tests/libintx.md4.perf [Nbra] [Nket]   # 4-center benchmark
```

### GPU Benchmarks

```bash
./build/tests/libintx.gpu.md3.perf [Nbra] [Nket]   # 3-center GPU benchmark
./build/tests/libintx.gpu.md4.perf [Nbra] [Nket]   # 4-center GPU benchmark
```

Benchmark args are the number of bra and ket shell pairs (default: 6000 each). The benchmarks sweep all angular momentum combinations up to LMAX with contraction depths K={1,1}, {1,5}, {5,5}. Output includes time per integral batch and integrals/second.

### Multi-GPU Support

The J-engine (`src/libintx/gpu/jengine/md/jengine.cc`) supports multi-GPU execution — it queries `gpu::device::count()` and distributes work across all available devices using a thread pool. Select GPUs with `CUDA_VISIBLE_DEVICES`:

```bash
# Use specific GPUs
CUDA_VISIBLE_DEVICES=0,1 ./build/tests/libintx.gpu.md3.perf 8000 8000

# Single GPU
CUDA_VISIBLE_DEVICES=0 ./build/tests/libintx.gpu.md3.perf
```

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

## Containers

Both Apptainer and Docker container definitions are provided for portable GPU benchmarking. Results are saved as JSON to `./results/<GPU_NAME>_<TIMESTAMP>.json` (override with `LIBINTX_RESULTS` env var). Each file includes GPU name, driver version, memory, hostname, timestamp, command, and full output.

### Apptainer

```bash
apptainer build libintx.sif libintx.def
apptainer run --nv libintx.sif libintx.gpu.md3.perf 8000 8000
```

### Docker

```bash
docker build -t libintx .
docker run --gpus all libintx libintx.gpu.md3.perf 8000 8000

# Save results to host
docker run --gpus all -v $(pwd)/results:/results -e LIBINTX_RESULTS=/results libintx libintx.gpu.md3.perf 8000 8000
```

### Available GPU binaries in the containers

**Benchmarks:**
```bash
libintx.gpu.md3.perf [Nbra] [Nket]
libintx.gpu.md4.perf [Nbra] [Nket]
```

**Tests:**
```bash
boys.gpu.test
libintx.gpu.md3.test
libintx.gpu.md4.test
```
