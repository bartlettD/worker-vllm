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

RUN apt-get update -y \
    && apt-get install -y python3-pip

# Install Python dependencies
COPY builder/requirements.txt /requirements.txt
RUN pip3 install --no-cache-dir --upgrade -r /requirements.txt && \
    rm /requirements.txt

# Install torch and vllm based on CUDA version
RUN pip3 install --no-cache-dir https://github.com/vllm-project/vllm/releases/download/v0.2.7/vllm-0.2.7+cu118-cp311-cp311-manylinux1_x86_64.whl

# Add source files
COPY src /src

# Setup for Option 2: Building the Image with the Model included
ARG MODEL_NAME=""
ARG MODEL_BASE_PATH="/runpod-volume"
ARG QUANTIZATION=""

ENV MODEL_BASE_PATH=$MODEL_BASE_PATH \
    MODEL_NAME=$MODEL_NAME \
    QUANTIZATION=$QUANTIZATION \
    HF_DATASETS_CACHE="${MODEL_BASE_PATH}/huggingface-cache/datasets" \
    HUGGINGFACE_HUB_CACHE="${MODEL_BASE_PATH}/huggingface-cache/hub" \
    HF_HOME="${MODEL_BASE_PATH}/huggingface-cache/hub" \
    HF_TRANSFER=1 
    
RUN --mount=type=secret,id=HF_TOKEN,required=false \
    if [ -f /run/secrets/HF_TOKEN ]; then \
        export HF_TOKEN=$(cat /run/secrets/HF_TOKEN); \
    fi && \
    if [ -n "$MODEL_NAME" ]; then \
        python3 /src/download_model.py --model $MODEL_NAME; \
    fi

ENV PYTHONPATH="/:/vllm-installation"

# Start the handler
CMD ["python3", "/src/handler.py"]