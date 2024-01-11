# Base image - Set default to CUDA 11.8
#ARG WORKER_CUDA_VERSION=11.8
FROM ghcr.io/bartlettd/vllm-cuda:main as builder

ARG WORKER_CUDA_VERSION=11.8 # Required duplicate to keep in scope

# Set Environment Variables
ENV WORKER_CUDA_VERSION=${WORKER_CUDA_VERSION} \
    HF_DATASETS_CACHE="/runpod-volume/huggingface-cache/datasets" \
    HUGGINGFACE_HUB_CACHE="/runpod-volume/huggingface-cache/hub" \
    TRANSFORMERS_CACHE="/runpod-volume/huggingface-cache/hub" \
    HF_TRANSFER=1 \
    TORCH_CUDA_ARCH_LIST="8.6 8.9"


# Install Python dependencies
COPY builder/requirements.txt /requirements.txt
RUN pip3 install --no-cache-dir --upgrade -r /requirements.txt && \
    rm /requirements.txt

# Install torch and vllm based on CUDA version
RUN pip3 install --no-cache-dir https://github.com/bartlettD/vllm-fork-for-sls-worker/releases/download/cuda-11.8-wheel/vllm-0.2.6-cp311-cp311-manylinux1_x86_64.whl

# Add source files
COPY src .

# Setup for Option 2: Building the Image with the Model included
ARG MODEL_NAME=""
ARG MODEL_BASE_PATH="/runpod-volume/"
ARG HF_TOKEN=""
ARG QUANTIZATION=""
RUN if [ -n "$MODEL_NAME" ]; then \
        export MODEL_BASE_PATH=$MODEL_BASE_PATH && \
        export MODEL_NAME=$MODEL_NAME && \
        python3.11 /download_model.py --model $MODEL_NAME; \
    fi && \
    if [ -n "$QUANTIZATION" ]; then \
        export QUANTIZATION=$QUANTIZATION; \
    fi

# Start the handler
CMD ["python3.11", "/handler.py"]
