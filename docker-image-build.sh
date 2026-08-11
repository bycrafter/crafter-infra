#!/bin/bash

# Herhangi bir hata oluşursa betiği derhal durdur
set -e


# Hata durumunda terminali açık tut
trap 'if [ $? -ne 0 ]; then echo "❌ Hata oluştu! Lütfen yukarıdaki hata mesajını inceleyin."; read -p "Çıkmak için bir tuşa basın..."; fi' EXIT

# =====================================================================
#             SUPPORTING METHODS (YARDIMCI METOTLAR)
# =====================================================================

source "$(dirname "$0")/lib-infra.sh"

# =====================================================================
#                 MAIN FLOW (ANA İŞ AKIŞI)
# =====================================================================
#
# Bu betik, 5 uygulama servisinin (account-manager, conference-manager,
# notification-manager, conference-web-api, conference-web-app) Docker
# image'larını kardeş repo'lardan ayrı ayrı build eder ve ardından
# docker compose ile altyapıyı ayağa kaldırır. start-infra.sh'ten farklı
# olarak AWS Secrets Manager'dan sır çekmez; mevcut ortam değişkenlerini
# (örn. .env dosyasından) kullanır.

echo "⚙️  YACS Docker Image Build Sihirbazı Çalışıyor..."

# 1. 5 Uygulama Repo'sunu Klonla (git kurulu değilse önce onu kur)
clone_application_repositories

# 2. Gereksinimleri Kontrol Et ve Gerekirse Kur
check_and_install_docker
check_and_install_docker_compose

build_java_application_images

build_node_application_images
