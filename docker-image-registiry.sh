#!/usr/bin/env bash
#
# docker-image-registiry.sh
#
# 5 uygulama servisinin (account-manager, conference-manager,
# notification-manager, conference-web-api, conference-web-app) daha önce
# `docker-image-build.sh` ile build edilmiş local Docker image'larını
# Docker Hub registry'sine otomatik olarak tag'ler ve push eder.
#
# Run `chmod +x docker-image-registiry.sh` before executing this script.
#
set -euo pipefail

source "$(dirname "$0")/lib-infra.sh"

echo "⚙️  YACS Docker Image Registry Push Sihirbazı Çalışıyor..."

check_and_install_docker
check_and_install_docker_compose

# 5 uygulama image'ını Docker Hub'a otomatik tag'le ve push et
push_application_images
