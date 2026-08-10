#!/bin/bash

# Herhangi bir hata oluşursa betiği derhal durdur
set -e

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
check_and_install_maven
check_and_install_node
check_and_install_npm

# 3. Uygulama Docker Image'larını Build Et
# 3a. Java repo'ları (3 repo: account-manager, conference-manager,
#     notification-manager)
build_java_application_images

