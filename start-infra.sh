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

echo "⚙️  YACS Altyapı Başlatma Sihirbazı Çalışıyor..."

# 1. Gereksinimleri Kontrol Et ve Gerekirse Kur
check_and_install_docker
check_and_install_docker_compose
check_and_install_unzip
check_and_install_jq
check_and_install_aws_cli

# 2. AWS Güvenlik Doğrulamasını Yap
verify_aws_credentials

# 3. Mevcut Docker Altyapısını Kapat
down_docker_infrastructure

# 4. AWS Secrets Manager'dan Verileri Çek ve Ortam Değişkenlerini Doldur
fetch_secrets_to_environment

# 5. Docker Compose Altyapısını Ayağa Kaldır
start_docker_infrastructure
