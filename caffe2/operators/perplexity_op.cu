/**
 * Copyright (c) 2016-present, Facebook, Inc.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#include "caffe2/core/context_gpu.h"
#include "caffe2/operators/perplexity_op.h"
#include "caffe2/utils/math.h"
#include <thrust/device_vector.h>
#include <thrust/transform_reduce.h>
#include <thrust/system/cuda/execution_policy.h>

namespace caffe2 {

struct perplexity_function
{
  perplexity_function(float p) : pow(p) {}
  __host__ __device__ float operator()(float x) const
  {
    return powf(1.0f/x, pow);
  }
  float pow;
};

template <>
bool PerplexityOp<float, CUDAContext>::RunOnDevice() {
  auto& X = Input(0);
  auto* Y = Output(0);

  DCHECK_EQ(X.ndim(), 1);
  int N = X.dim32(0);

  Y->Resize(vector<TIndex>());
  float* Ydata = Y->mutable_data<float>();
  const float* Xdata = X.data<float>();

  float perplexity = thrust::transform_reduce(
      #if THRUST_VERSION >= 100800
        thrust::cuda::par.on(context_.cuda_stream()),
      #endif  // THRUST_VERSION >= 100800
      Xdata, Xdata + N,
      perplexity_function(1.0f/N),
      1.0f,
      thrust::multiplies<float>());

  math::Set<float, CUDAContext>(1, perplexity, Ydata, &context_);
  return true;
}

REGISTER_CUDA_OPERATOR(Perplexity, PerplexityOp<float, CUDAContext>);
}  // namespace caffe2
