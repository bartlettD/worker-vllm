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
RUN --mount=type=cache,target=/root/.cache/pip \
    python3.11 -m pip install --upgrade pip && \
    python3.11 -m pip install --upgrade -r /requirements.txt && \
    rm /requirements.txt

# Install torch and vllm based on CUDA version
RUN python3.11 -m pip install -e git+https://github.com/runpod/vllm-fork-for-sls-worker.git@cuda-11.8#egg=vllm; \
    rm -rf /root/.cache/pip

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
