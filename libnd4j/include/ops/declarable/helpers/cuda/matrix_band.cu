/*******************************************************************************
 * Copyright (c) 2015-2018 Skymind, Inc.
 *
 * This program and the accompanying materials are made available under the
 * terms of the Apache License, Version 2.0 which is available at
 * https://www.apache.org/licenses/LICENSE-2.0.
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
 * WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
 * License for the specific language governing permissions and limitations
 * under the License.
 *
 * SPDX-License-Identifier: Apache-2.0
 ******************************************************************************/

//
//  @author George A. Shulinok <sgazeos@gmail.com>
//
#include <ops/declarable/helpers/matrix_band.h>
#include <TAD.h>
#include <cuda_exception.h>
#include <ShapeUtils.h>

namespace nd4j {
namespace ops {
namespace helpers {

    template <typename T>
    static __global__ void matrixBandKernel(void* inputBuffer, Nd4jLong* inputShape,
            void* outputBuffer, Nd4jLong* outputShape, Nd4jLong lowerBand, Nd4jLong upperBand, Nd4jLong* tadOnlyInputShapeInfo,  Nd4jLong* tadInputOffsets,
                                            Nd4jLong* tadOnlyOutputShapeInfo, Nd4jLong* tadOutputOffsets, Nd4jLong numTads, Nd4jLong inputLength) {
        int totalThreads = blockDim.x;
        Nd4jLong rows = shape::sizeAt(inputShape, -2);
        Nd4jLong cols = shape::sizeAt(inputShape, -1);
        for (Nd4jLong e = blockIdx.x; e < numTads; e += gridDim.x) {
            auto yOffset = tadInputOffsets[e];
            auto xOffset = tadOutputOffsets[e];
            for (Nd4jLong i = blockIdx.y; i < rows; i += gridDim.y) {
                for (Nd4jLong j = threadIdx.x; j < cols; j += totalThreads) {
                    Nd4jLong coords[2] = {i, j};
                    Nd4jLong tadOffsetOut = shape::getOffset(0, shape::shapeOf(tadOnlyOutputShapeInfo),
                                                             shape::stride(tadOnlyOutputShapeInfo), coords, 2);
                    Nd4jLong tadOffsetIn = shape::getOffset(0, shape::shapeOf(tadOnlyInputShapeInfo),
                                                            shape::stride(tadOnlyInputShapeInfo), coords, 2);
                    //shape::getIndexOffset(j, tadOnlyOutputShapeInfo, inputLength)
                    if (i >= j) { // check lower diagonals
                        if (lowerBand > 0) {
                            if ((i - j) > lowerBand)
                                *(reinterpret_cast<T *>(outputBuffer) + xOffset + tadOffsetOut) = T(0);
                            else
                                *(reinterpret_cast<T *>(outputBuffer) + xOffset + tadOffsetOut) = *(
                                        reinterpret_cast<T const *>(inputBuffer) + yOffset + tadOffsetIn);
                        }
                    } else if (j > i) {
                        if (upperBand > 0)
                            if ((j - i) > upperBand)
                                *(reinterpret_cast<T *>(outputBuffer) + xOffset + tadOffsetOut) = T(0);
                            else
                                *(reinterpret_cast<T *>(outputBuffer) + xOffset + tadOffsetOut) = *(
                                        reinterpret_cast<T const *>(inputBuffer) + yOffset + tadOffsetIn);
                    }
//                if ((i >= j) && (i - j) <= lowerBand && (j - i) <= upperBand) // with in band
//                    *(reinterpret_cast<T*>(outputBuffer) + xOffset + tadOffsetOut) = *(reinterpret_cast<T const*>(inputBuffer) + yOffset + tadOffsetIn);
                    //else
                    //    *(reinterpret_cast<T*>(outputBuffer) + xOffset + tadOffsetOut) = T(0);
                }
            }
        }

    }

    template <typename T>
    void matrixBandPart_(graph::LaunchContext* context, NDArray* input, NDArray* output, Nd4jLong lowerBand, Nd4jLong upperBand) {
        dim3 launchDims(256, 512, 8192);
        auto stream = context->getCudaStream();

        std::vector<int> lastDims({input->rankOf() - 2, input->rankOf() - 1});
        std::vector<int> dimsToExclude = ShapeUtils::evalDimsToExclude(input->rankOf(), lastDims);
        const Nd4jLong numTads = ShapeUtils::getNumOfSubArrs(input->getShapeInfo(), dimsToExclude);
        shape::TAD tadInput;
        tadInput.init(input->getShapeInfo(), lastDims.data(), lastDims.size());
        tadInput.createTadOnlyShapeInfo();
        tadInput.createOffsets();
        if (!input->isActualOnDeviceSide())
            input->syncToDevice();

        shape::TAD tadOutput;
        tadOutput.init(output->getShapeInfo(), lastDims.data(), lastDims.size());
        tadOutput.createTadOnlyShapeInfo();
        tadOutput.createOffsets();
        if (!input->isActualOnDeviceSide())
            input->syncToDevice();

        // prepare input arrays for prepareDataForCuda function
        std::vector<std::pair<void*,size_t>> hostData;
        hostData.emplace_back(tadInput.tadOnlyShapeInfo, shape::shapeInfoByteLength(tadInput.tadOnlyShapeInfo));	// 1 -- xTadShapeInfo
        hostData.emplace_back(tadInput.tadOffsets, tadInput.numTads * sizeof(Nd4jLong));							// 2 -- xTadOffsets
        hostData.emplace_back(tadOutput.tadOnlyShapeInfo, shape::shapeInfoByteLength(tadOutput.tadOnlyShapeInfo));	// 1 -- xTadShapeInfo
        hostData.emplace_back(tadOutput.tadOffsets, tadOutput.numTads * sizeof(Nd4jLong));							// 2 -- xTadOffsets
        std::vector<Nd4jLong*> tadsDevice(hostData.size(), nullptr);

        // create cuda stream and LaunchContext
        cudaError_t cudaResult;
        //cudaStream_t stream;
        //cudaResult = cudaStreamCreate(&stream);	ASSERT_EQ(0, cudaResult);
        //cudaStream_t* stream = this->getContext()->getCudaStream();
        // allocate required amount of global device memory and copy host data to it
//    cudaResult = allocateDeviceMem(*pLc, devicePtrs, hostData);	ASSERT_EQ(0, cudaResult);
        for(int i = 0; i < tadsDevice.size(); ++i) {
            cudaResult = cudaMalloc(reinterpret_cast<void **>(&tadsDevice[i]), hostData[i].second);
            if(cudaResult != 0) throw cuda_exception::build("Cannot allocate memory for tads on device", cudaResult);
            cudaResult = cudaMemcpy(tadsDevice[i], hostData[i].first, hostData[i].second, cudaMemcpyHostToDevice);
            if(cudaResult != 0) throw cuda_exception::build("Cannot copy memory block for tads on device", cudaResult);
        }

        matrixBandKernel<T><<<launchDims.x, launchDims.y, launchDims.z, *stream>>>(input->getSpecialBuffer(),
                input->getSpecialShapeInfo(), output->getSpecialBuffer(), output->getSpecialShapeInfo(),
                lowerBand, upperBand, tadsDevice[0], tadsDevice[1], tadsDevice[2], tadsDevice[3], numTads, input->lengthOf());

        for(int i = 0; i < tadsDevice.size(); ++i) {
            cudaResult = cudaFree(tadsDevice[i]);
            if(cudaResult != 0) throw cuda_exception::build("Cannot release memory block for tads on device", cudaResult);
        }
    }

    void matrixBandPart(graph::LaunchContext* context, NDArray* input, NDArray* output, Nd4jLong lowerBand, Nd4jLong upperBand) {
        BUILD_SINGLE_SELECTOR(input->dataType(), matrixBandPart_, (context, input, output, lowerBand, upperBand), FLOAT_TYPES);
    }
    BUILD_SINGLE_TEMPLATE(template void matrixBandPart_, (graph::LaunchContext* context, NDArray* input, NDArray* output, Nd4jLong lowerBand, Nd4jLong upperBand), FLOAT_TYPES);
}
}
}
