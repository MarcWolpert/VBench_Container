#Example to build:
# docker build -t vbench .

#Example command to run:
# docker run --gpus all -it vbench bash -v /path/to/videos:/workspace/videos

FROM nvidia/cuda:12.1.0-devel-ubuntu22.04


LABEL org.opencontainers.image.title="VBench Evaluation Framework"
LABEL org.opencontainers.image.description="Docker image for VBench video generation evaluation with CUDA support, uv, and opengl."
LABEL org.opencontainers.image.version="0.2.0"
LABEL org.opencontainers.image.authors="Marc Wolpert <mewolpert@gmail.com>"
LABEL org.opencontainers.image.url="https://github.com/mwolpe/VBENCH_Container"
LABEL org.opencontainers.image.source="https://github.com/Vchitect/VBench"
LABEL org.opencontainers.image.licenses="Apache-2.0"
LABEL name="vbench"
LABEL version="0.2"
LABEL description="VBench Docker Image with uv package manager"

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1

# Make directory for workspace
RUN mkdir -p /workspace
# Set working directory
WORKDIR /workspace

# Install system dependencies
# opengl required for various benchmarks
# only background_consistency, aesthetic_quality, scene, temporal_style, 
# overall_consistency, and appearance_style run without opengl
RUN apt-get update && apt-get install -y \
    git \
    wget \
    curl \
    tar \
    libgl1-mesa-glx \
    libglib2.0-0 \
    unzip

# Install uv package manager
RUN curl -LsSf https://astral.sh/uv/install.sh | sh
ENV PATH="/root/.local/bin:${PATH}"

# Clone VBench repository
RUN git clone https://github.com/Vchitect/VBench.git /workspace/VBench

# Set up Python virtual environment with uv
WORKDIR /workspace/VBench

# Make all shell scripts executable
RUN chmod +x scripts/*.sh

#activate venv by default
RUN uv venv /workspace/.venv --python 3.10
ENV VIRTUAL_ENV=/workspace/.venv
ENV PATH="/workspace/.venv/bin:${PATH}"

RUN uv pip install \
    torch==2.1.0 \
    torchvision==0.16.0 \
    torchaudio==2.1.0 \
    --index-url https://download.pytorch.org/whl/cu118
    
RUN uv pip install gdown==5.2.0


# Install VBench dependencies with uv (pins all transitive dependencies)
RUN if [ -f requirements.txt ]; then \
        uv pip install -r requirements.txt; \
    fi

RUN uv pip install --no-build-isolation detectron2@git+https://github.com/facebookresearch/detectron2.git

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD python -c "import torch; assert torch.cuda.is_available()" || exit 1

#when building the docker image, the videos directory will be mounted to the container
VOLUME ["workspace/videos"]

CMD ["bash"]

#To run the example benchmark with example videos, run the following command:
# ./scripts/download_videocrafter1.sh && ./scripts/run_videocrafter1.sh