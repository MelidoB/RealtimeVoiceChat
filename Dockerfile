# Stage 1: Builder Stage - Install dependencies including build tools and CUDA toolkit components
FROM nvidia/cuda:12.1.1-cudnn8-devel-ubuntu22.04 AS builder

# Avoid prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Fix GPG issues and install Python 3.10, pip, build essentials, git, and other system dependencies
RUN echo 'Acquire::AllowInsecureRepositories "true";' > /etc/apt/apt.conf.d/99insecure \
    && echo 'Acquire::AllowDowngradeToInsecureRepositories "true";' >> /etc/apt/apt.conf.d/99insecure \
    && apt-get update --allow-releaseinfo-change \
    && apt-get install -y --allow-unauthenticated --no-install-recommends \
    ca-certificates \
    gnupg \
    lsb-release \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get update --allow-releaseinfo-change \
    && apt-get install -y --allow-unauthenticated --no-install-recommends \
    python3.10 \
    python3-pip \
    python3.10-dev \
    python3.10-venv \
    build-essential \
    git \
    libsndfile1 \
    libportaudio2 \
    ffmpeg \
    portaudio19-dev \
    python3-setuptools \
    python3.10-distutils \
    ninja-build \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Make python3.10 the default python/pip
RUN update-alternatives --install /usr/bin/python python /usr/bin/python3.10 1 && \
    update-alternatives --install /usr/bin/pip pip /usr/bin/pip3 1

# Create a non-root user and group first, so we can use it for chown
# This is the main fix: the group is now named 'appuser'
RUN groupadd --gid 1001 appuser && \
    useradd --uid 1001 --gid 1001 --create-home appuser

# Set working directory
WORKDIR /app

# Upgrade pip
RUN pip install --no-cache-dir --upgrade pip

# Install PyTorch with CUDA 12.1 support
RUN pip install --no-cache-dir \
    torch==2.5.1+cu121 \
    torchaudio==2.5.1+cu121 \
    torchvision==0.20.1 \
    --index-url https://download.pytorch.org/whl/cu121

# Install DeepSpeed
ENV DS_BUILD_TRANSFORMER=1
ENV DS_BUILD_CPU_ADAM=0
ENV DS_BUILD_FUSED_ADAM=0
ENV DS_BUILD_UTILS=0
ENV DS_BUILD_OPS=0

RUN echo "Building DeepSpeed with flags: DS_BUILD_TRANSFORMER=${DS_BUILD_TRANSFORMER}, DS_BUILD_CPU_ADAM=${DS_BUILD_CPU_ADAM}, DS_BUILD_FUSED_ADAM=${DS_BUILD_FUSED_ADAM}, DS_BUILD_UTILS=${DS_BUILD_UTILS}, DS_BUILD_OPS=${DS_BUILD_OPS}" && \
    pip install --no-cache-dir deepspeed \
    || (echo "DeepSpeed install failed. Check build logs above." && exit 1)

# Copy requirements file first to leverage Docker cache
# Use symbolic name for ownership
COPY --chown=appuser:appuser requirements.txt .

# Install remaining Python dependencies from requirements.txt
RUN pip install --no-cache-dir --prefer-binary -r requirements.txt \
    || (echo "pip install -r requirements.txt FAILED." && exit 1)

# Pin ctranslate2 to a compatible version (cuDNN 8 compatible)
RUN pip install --no-cache-dir "ctranslate2<4.5.0"

# Copy the application code
# Use symbolic name for ownership
COPY --chown=appuser:appuser code/ ./code/

# --- Stage 2: Runtime Stage ---
# Base image still needs CUDA toolkit for PyTorch/DeepSpeed/etc in the app
FROM nvidia/cuda:12.1.1-cudnn8-devel-ubuntu22.04

# Avoid prompts
ENV DEBIAN_FRONTEND=noninteractive

# Install runtime dependencies for the APP + gosu
RUN echo 'Acquire::AllowInsecureRepositories "true";' > /etc/apt/apt.conf.d/99insecure \
    && echo 'Acquire::AllowDowngradeToInsecureRepositories "true";' >> /etc/apt/apt.conf.d/99insecure \
    && apt-get update --allow-releaseinfo-change \
    && apt-get install -y --allow-unauthenticated --no-install-recommends \
    ca-certificates \
    gnupg \
    lsb-release \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get update --allow-releaseinfo-change \
    && apt-get install -y --allow-unauthenticated --no-install-recommends \
    python3.10 \
    python3-pip \
    python3.10-dev \
    libsndfile1 \
    ffmpeg \
    libportaudio2 \
    python3-setuptools \
    python3.10-distutils \
    ninja-build \
    build-essential \
    g++ \
    curl \
    gosu \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Make python3.10 the default python
RUN update-alternatives --install /usr/bin/python python /usr/bin/python3.10 1 && \
    update-alternatives --install /usr/bin/pip pip /usr/bin/pip3 1

# Create the same non-root user and group as in the builder stage
# This ensures the user/group exists in the final image
RUN groupadd --gid 1001 appuser && \
    useradd --uid 1001 --gid 1001 --create-home appuser

# Set working directory for the application
WORKDIR /app/code

# Copy installed Python packages from the builder stage
RUN mkdir -p /usr/local/lib/python3.10/dist-packages
COPY --chown=appuser:appuser --from=builder /usr/local/lib/python3.10/dist-packages /usr/local/lib/python3.10/dist-packages

# Copy the application code from the builder stage
COPY --chown=appuser:appuser --from=builder /app/code /app/code

# Ensure directories are owned by appuser - This prepares the image layers correctly
# The entrypoint will handle runtime permissions for volumes/cache
RUN mkdir -p /home/appuser/.cache && \
    chown -R appuser:appuser /app && \
    chown -R appuser:appuser /home/appuser

# Copy and set permissions for entrypoint script
# Use symbolic name for ownership
COPY --chown=appuser:appuser entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# --- REMOVED USER appuser --- The container will start as root.

# --- Keep ENV vars ---
ENV HOME=/home/appuser
ENV CUDA_HOME=/usr/local/cuda
ENV PATH="${CUDA_HOME}/bin:${PATH}"
ENV LD_LIBRARY_PATH="${CUDA_HOME}/lib64:${LD_LIBRARY_PATH}"
ENV PYTHONUNBUFFERED=1
ENV MAX_AUDIO_QUEUE_SIZE=50
ENV LOG_LEVEL=INFO
ENV NVIDIA_VISIBLE_DEVICES=all
ENV NVIDIA_DRIVER_CAPABILITIES=compute,utility
ENV RUNNING_IN_DOCKER=true
ENV DS_BUILD_OPS=1
ENV DS_BUILD_CPU_ADAM=0
ENV DS_BUILD_FUSED_ADAM=0
ENV DS_BUILD_UTILS=0
ENV DS_BUILD_TRANSFORMER=1
ENV HF_HOME=${HOME}/.cache/huggingface
ENV TORCH_HOME=${HOME}/.cache/torch

# Expose the port the FastAPI application runs on
EXPOSE 8000

# Set the entrypoint script - This runs as root
ENTRYPOINT ["/entrypoint.sh"]
# Define the default command - This is passed as "$@" to the entrypoint script
CMD ["python", "-m", "uvicorn", "server:app", "--host", "0.0.0.0", "--port", "8000"]