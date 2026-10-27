# syntax=docker/dockerfile:1

# ──────────────────────────────────────────────────────────────
# Base image & metadata
# ──────────────────────────────────────────────────────────────
ARG ALMA_VERSION=9
FROM almalinux:${ALMA_VERSION}

# ──────────────────────────────────────────────────────────────
# Required min specs for Control-M Agent
# ──────────────────────────────────────────────────────────────
LABEL \
  cpu.required="2" \
  memory.required="6GB" \
  spec.cpu2017.integer.rate="10"

ENV JAVA_HOME=/usr/lib/jvm/temurin-25-jdk \
  PYTHONUNBUFFERED=1

# Use bash with pipefail for all RUN commands
SHELL ["/bin/bash", "-eo", "pipefail", "-c"]

# ──────────────────────────────────────────────────────────────
# 1) Install OS packages
#    • psmisc (pstree), procps-ng, hostname, which, iproute
#    • pkgconf-pkg-config
#    • libnsl + libxcrypt-compat (RHEL 9 compat libs)
#    • tar, gzip, bzip2, zip, unzip
#    • python3, pip
#    • Temurin JDK 25 @ https://adoptium.net/temurin/releases
#    curl-minimal is swapped for full curl (--allowerasing)
# ──────────────────────────────────────────────────────────────
RUN printf '%s\n' \
    '[Adoptium]' \
    'name=Adoptium' \
    'baseurl=https://packages.adoptium.net/artifactory/rpm/rhel/$releasever/$basearch' \
    'enabled=1' \
    'gpgcheck=1' \
    'gpgkey=https://packages.adoptium.net/artifactory/api/gpg/key/public' \
    > /etc/yum.repos.d/adoptium.repo \
  && dnf install -y --allowerasing --setopt=install_weak_deps=False \
  wget \
  curl \
  gnupg2 \
  ca-certificates \
  psmisc \
  procps-ng \
  hostname \
  which \
  findutils \
  iproute \
  net-tools \
  libsigsegv \
  mpfr \
  ncurses-libs \
  libnsl \
  libxcrypt-compat \
  cups \
  jq \
  pkgconf-pkg-config \
  sudo \
  tar \
  gzip \
  bzip2 \
  zip \
  unzip \
  python3 \
  python3-pip \
  temurin-25-jdk \
  && dnf clean all \
  && rm -rf /var/cache/dnf

ENV PATH="$JAVA_HOME/bin:$PATH"

# ──────────────────────────────────────────────────────────────
# 2) Create user 'controlm' and supporting directories
# ──────────────────────────────────────────────────────────────
RUN groupadd -r controlm \
  && useradd -r -g controlm -d /opt/ctm -s /bin/bash -m controlm \
  && chmod 755 /opt/ctm \
  && echo 'controlm ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers \
  && mkdir -p /home/controlm/se_storage \
  && chown -R controlm:controlm /home/controlm

USER controlm
WORKDIR /opt/ctm
ENV HOME=/opt/ctm

# ──────────────────────────────────────────────────────────────
# 3) Download & install the CTM CLI into a Python venv
# ──────────────────────────────────────────────────────────────
RUN wget -q \
  https://bmc-prod-saas-agent-application-artifacts.s3.us-west-2.amazonaws.com/9.0.22.100/extracted/5718/root/apps/DEV/9.0.22.100/install_ctm_cli.py \
  && chmod +x install_ctm_cli.py \
  && python3 -m venv venv \
  && ./venv/bin/pip install --upgrade pip setuptools wheel \
  && ./venv/bin/python install_ctm_cli.py \
  && rm -rf install_ctm_cli.py extracted_package .cache

# Ensure `ctm` is on PATH
ENV PATH="/opt/ctm/venv/bin:$PATH"

# ──────────────────────────────────────────────────────────────
# 4) Pre-create persistent agent directories
#    Ensures named volumes inherit controlm:controlm ownership
#    on first creation — agent populates contents at runtime
# ──────────────────────────────────────────────────────────────
RUN mkdir -p \
  /opt/ctm/ctm/alert \
  /opt/ctm/ctm/backup \
  /opt/ctm/ctm/capdef \
  /opt/ctm/ctm/cfg_backup \
  /opt/ctm/ctm/cm \
  /opt/ctm/ctm/dailylog \
  /opt/ctm/ctm/data \
  /opt/ctm/ctm/measure \
  /opt/ctm/ctm/metric \
  /opt/ctm/ctm/onstmt \
  /opt/ctm/ctm/pid \
  /opt/ctm/ctm/procid \
  /opt/ctm/ctm/proclog \
  /opt/ctm/ctm/runtime \
  /opt/ctm/ctm/scripts \
  /opt/ctm/ctm/status \
  /opt/ctm/ctm/svrlocks \
  /opt/ctm/ctm/sysout \
  /opt/ctm/ctm/temp

# ──────────────────────────────────────────────────────────────
# 5) Verify installations
# ──────────────────────────────────────────────────────────────
RUN python3 --version \
  && pip --version \
  && java -version \
  && which ctm \
  && pstree --version \
  && pkg-config --version

# ──────────────────────────────────────────────────────────────
# 6) Provisioning entrypoint (pass real values at runtime)
#    CTM_ENDPOINT, CTM_API_TOKEN, CTM_AGENT_TAG, CTM_AGENT_NAME
#    must be injected at runtime — never bake secrets into the image
# ──────────────────────────────────────────────────────────────
ENV \
  BMC_INST_JAVA_HOME=${JAVA_HOME} \
  CTM_ENV_NAME=default

COPY --chown=controlm:controlm entrypoint.sh /opt/ctm/entrypoint.sh
RUN chmod +x /opt/ctm/entrypoint.sh

ENTRYPOINT ["/opt/ctm/entrypoint.sh"]
CMD ["bash"]
