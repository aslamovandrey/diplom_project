FROM jenkins/jenkins:lts-jdk21

USER root

ARG DOCKER_GID=999

RUN apt-get update && \
    apt-get install -y \
    curl \
    unzip \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release && \
    rm -rf /var/lib/apt/lists/*

# Docker CLI

RUN curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
    gpg --dearmor -o /usr/share/keyrings/docker.gpg

RUN echo \
    "deb [arch=amd64 signed-by=/usr/share/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu jammy stable" \
    > /etc/apt/sources.list.d/docker.list

RUN apt-get update && \
    apt-get install -y docker-ce-cli

# kubectl

RUN curl -LO "https://dl.k8s.io/release/v1.33.0/bin/linux/amd64/kubectl" && \
    install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl && \
    rm kubectl

# Helm

RUN curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# yc CLI

RUN curl -sSL https://storage.yandexcloud.net/yandexcloud-yc/install.sh \
    | bash -s -- -i /opt/yc -n

RUN ln -s /opt/yc/bin/yc /usr/local/bin/yc

# Docker socket permissions

RUN groupadd -g ${DOCKER_GID} dockerhost && \
    usermod -aG dockerhost jenkins

RUN mkdir -p /usr/local/yandex-cloud/bin && \
    ln -s /usr/local/bin/yc /usr/local/yandex-cloud/bin/yc

USER jenkins