#ifndef LIBINTX_GPU_ENGINE_H
#define LIBINTX_GPU_ENGINE_H

#include "libintx/ao/engine.h"
#include "libintx/shell.h"
#include "libintx/gpu/forward.h"

#include <vector>
#include <array>
#include <cstddef>
#include <memory>

namespace libintx::gpu {

  template<int N>
  struct IntegralEngine;

  template<>
  struct IntegralEngine<3> : libintx::ao::IntegralEngine<3> {
    virtual ~IntegralEngine() = default;
    virtual void compute(
      Operator,
      const std::vector<Index1> &bra,
      const std::vector<Index2> &ket,
      double*,
      const std::array<size_t,2>&
    ) = 0;
    void compute(
      Operator op,
      const std::vector<Index1> &bra,
      const std::vector<Index2> &ket,
      BraKet<const double*>,
      double *V,
      const std::array<size_t,2> &dims
    ) override {
      this->compute(op, bra, ket, V, dims);
    }
  };

  template<>
  struct IntegralEngine<4> : libintx::ao::IntegralEngine<4> {
    virtual ~IntegralEngine() = default;
    virtual void compute(
      Operator,
      const std::vector<Index2> &bra,
      const std::vector<Index2> &ket,
      double*,
      const std::array<size_t,2>&
    ) = 0;
    void compute(
      Operator op,
      const std::vector<Index2> &bra,
      const std::vector<Index2> &ket,
      BraKet<const double*>,
      double *V,
      const std::array<size_t,2> &dims
    ) override {
      this->compute(op, bra, ket, V, dims);
    }
    size_t max_memory = 0;
  };

  template<int N>
  std::unique_ptr< IntegralEngine<N> > integral_engine(
    const Basis<Gaussian>& bra,
    const Basis<Gaussian>& ket,
    const gpuStream_t& stream
  ) = delete;

  template<>
  std::unique_ptr< IntegralEngine<3> > integral_engine(
    const Basis<Gaussian>& bra,
    const Basis<Gaussian>& ket,
    const gpuStream_t& stream
  );

  template<>
  std::unique_ptr< IntegralEngine<4> > integral_engine(
    const Basis<Gaussian>& bra,
    const Basis<Gaussian>& ket,
    const gpuStream_t& stream
  );

}

#endif /* LIBINTX_GPU_ENGINE_H */
