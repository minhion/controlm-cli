# syntax=docker/dockerfile:1

# ──────────────────────────────────────────────────────────────
# Base image & metadata
# 24.04 not supported by BMC yet!!
# ──────────────────────────────────────────────────────────────
FROM ubuntu:22.04

# ──────────────────────────────────────────────────────────────
# Required min specs for Control-M Agent
# ──────────────────────────────────────────────────────────────
LABEL \
  cpu.required="2" \
  memory.required="6GB" \
  spec.cpu2017.integer.rate="10"

ENV DEBIAN_FRONTEND=noninteractive \
  JAVA_HOME=/usr/lib/jvm/temurin-21-jdk-amd64 \
  PYTHONUNBUFFERED=1

# Use bash with pipefail for all RUN commands
SHELL ["/bin/bash", "-eo", "pipefail", "-c"]

# ──────────────────────────────────────────────────────────────
# 1) Install OS packages
#    • psmisc (pstree)  
#    • pkg-config  
#    • libglib2.0-0 + libglib2.0-dev  
#    • tar, gzip, bzip2, zip, unzip  
#    • python3-venv, pip  
#    • Temurin JDK 21 @ https://adoptium.net/temurin/releases
# ──────────────────────────────────────────────────────────────
RUN apt-get update \
  && apt-get install -y --no-install-recommends \
  wget \
  curl \
  gnupg \
  ca-certificates \
  psmisc \
  net-tools \
  libsigsegv2 \
  libmpfr6 \
  libtinfo5 \
  cups \
  jq \
  pkg-config \
  sudo \
  tar \
  gzip \
  bzip2 \
  zip \
  unzip \
  python3 \
  python3-pip \
  python3-venv \
  && wget -qO- https://packages.adoptium.net/artifactory/api/gpg/key/public \
  | apt-key add - \
  && echo "deb https://packages.adoptium.net/artifactory/deb \
  $(awk -F= '/^VERSION_CODENAME/{print $2}' /etc/os-release) main" \
  > /etc/apt/sources.list.d/adoptium.list \
  && apt-get update \
  && apt-get install -y --no-install-recommends temurin-21-jdk \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

ENV PATH="$JAVA_HOME/bin:$PATH"

# ──────────────────────────────────────────────────────────────
# 2) Create user 'controlm' & add no sudoers
# ──────────────────────────────────────────────────────────────
RUN groupadd -r controlm \
  && useradd -r -g controlm -d /opt/ctm -s /bin/bash -m controlm && \
  echo 'controlm ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers

USER controlm
WORKDIR /opt/ctm
ENV HOME=/opt/ctm

# ──────────────────────────────────────────────────────────────
# 3) Download & install the CTM CLI into a Python venv
# ──────────────────────────────────────────────────────────────
RUN wget -q \
  https://bmc-prod-saas-agent-application-artifacts.s3.us-west-2.amazonaws.com/9.0.22.006/extracted/4766/root/apps/DEV/9.0.22.000/install_ctm_cli.py \
  && chmod +x install_ctm_cli.py \
  && python3 -m venv venv \
  && ./venv/bin/pip install --upgrade pip setuptools wheel \
  && ./venv/bin/python install_ctm_cli.py

# Ensure `ctm` is on PATH
ENV PATH="/opt/ctm/venv/bin:$PATH"

# ──────────────────────────────────────────────────────────────
# 4) Verify installations
# ──────────────────────────────────────────────────────────────
RUN python3 --version \
  && pip --version \
  && java -version \
  && which ctm \
  && pstree --version \
  && pkg-config --version

# ──────────────────────────────────────────────────────────────
# 5) Provisioning entrypoint (pass real values at runtime)
# ──────────────────────────────────────────────────────────────
ENV \
  BMC_INST_JAVA_HOME=${JAVA_HOME} \
  CTM_ENV_NAME=default \
  CTM_ENDPOINT="" \
  CTM_API_TOKEN=""

# Copy your entrypoint script (make sure it's executable)
COPY --chown=controlm:controlm entrypoint.sh /opt/ctm/entrypoint.sh
RUN chmod +x /opt/ctm/entrypoint.sh

ENTRYPOINT ["/opt/ctm/entrypoint.sh"]
CMD ["bash"]
