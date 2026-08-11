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

echo "⚙️  YACS Repo Klonlama Sihirbazı Çalışıyor..."

# 1. Git'in kurulu olduğundan emin ol
if ! command -v git &> /dev/null; then
    echo "❌ 'git' bulunamadı! Lütfen git'i kurup tekrar deneyin."
    exit 1
fi

# 2. Tüm uygulama repo'larını crafter-infra ile aynı üst dizine klonla
clone_application_repositories
