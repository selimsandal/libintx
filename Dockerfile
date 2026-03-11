FROM nvcr.io/nvidia/cuda:13.1.1-cudnn-devel-ubuntu24.04

RUN apt-get update && apt-get install -y --no-install-recommends \
        cmake \
        g++ \
        make \
        jq \
        libopenblas-dev \
        liblapacke-dev \
    && rm -rf /var/lib/apt/lists/*

COPY . /opt/libintx

WORKDIR /opt/libintx/build

RUN cmake .. \
        -DLIBINTX_CUDA=ON \
        -DCMAKE_CUDA_ARCHITECTURES="80;89;90;100;120" \
        -DCMAKE_BUILD_TYPE=Release \
    && cmake --build . --target libintx.gpu.md3.perf libintx.gpu.md4.perf -j$(nproc) \
    && cmake --build . --target libintx.gpu.md3.test libintx.gpu.md4.test boys.gpu.test -j$(nproc) \
    && rm -rf CMakeFiles src/libintx/gpu/CMakeFiles

ENV PATH="/opt/libintx/build/tests:${PATH}"

COPY <<'ENTRYPOINT' /usr/local/bin/libintx-bench
#!/bin/bash
OUTDIR="${LIBINTX_RESULTS:-./results}"
mkdir -p "$OUTDIR"

GPU_NAME=$(nvidia-smi --query-gpu=name --format=csv,noheader | head -1)
GPU_DRIVER=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader | head -1)
GPU_MEMORY=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits | head -1)
GPU_SLUG=$(echo "$GPU_NAME" | tr ' ' '_')
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUTFILE="${OUTDIR}/${GPU_SLUG}_${TIMESTAMP}.json"

OUTPUT=$("$@" 2>&1)
EXIT_CODE=$?

echo "$OUTPUT"

jq -n \
  --arg gpu "$GPU_NAME" \
  --arg driver "$GPU_DRIVER" \
  --arg memory_mb "$GPU_MEMORY" \
  --arg date "$(date -Iseconds)" \
  --arg hostname "$(hostname)" \
  --arg command "$*" \
  --argjson exit_code "$EXIT_CODE" \
  --arg output "$OUTPUT" \
  '{
    gpu: {
      name: $gpu,
      driver: $driver,
      memory_mb: ($memory_mb | tonumber)
    },
    system: {
      hostname: $hostname,
      date: $date
    },
    benchmark: {
      command: $command,
      exit_code: $exit_code,
      output: $output
    }
  }' > "$OUTFILE"

echo "Results saved to: $OUTFILE" >&2
ENTRYPOINT
RUN chmod +x /usr/local/bin/libintx-bench

ENTRYPOINT ["libintx-bench"]
