#!/bin/bash

# --- İŞLETİM SİSTEMİ TESPİT METODU ---
detect_os() {
    local uname_out
    uname_out=$(uname -s)
    case "$uname_out" in
        Linux*)     echo "Linux";;
        Darwin*)    echo "Mac";;
        CYGWIN*|MINGW*|MSYS*) echo "Windows";;
        *)          echo "Unknown";;
    esac
}

# --- EVRENSEL SİTEM PAKETİ KURMA METODU ---
install_system_package() {
    local PACKAGE_NAME=$1
    local OS
    OS=$(detect_os)

    if [ "$OS" = "Mac" ]; then
        brew install "$PACKAGE_NAME"
    elif [ "$OS" = "Linux" ]; then
        if command -v apt-get &> /dev/null; then
            sudo apt-get update && sudo apt-get install -y "$PACKAGE_NAME"
        elif command -v dnf &> /dev/null; then
            sudo dnf install -y "$PACKAGE_NAME"
        elif command -v yum &> /dev/null; then
            sudo yum install -y "$PACKAGE_NAME"
        elif command -v pacman &> /dev/null; then
            sudo pacman -Sy --noconfirm "$PACKAGE_NAME"
        else
            echo "❌ Linux paket yöneticisi bulunamadı. Lütfen '$PACKAGE_NAME' paketini manuel kurun."
            exit 1
        fi
    elif [ "$OS" = "Windows" ]; then
        # Windows 10/11'in yerleşik paket yöneticisi olan winget'i tetikliyoruz
        if command -v winget.exe &> /dev/null; then
            echo "🪟 Windows paket yöneticisi (winget) ile '$PACKAGE_NAME' kuruluyor..."
            if [ "$PACKAGE_NAME" = "jq" ]; then
                winget.exe install -e --id jqlang.jq --accept-source-agreements --accept-package-agreements --silent
            elif [ "$PACKAGE_NAME" = "unzip" ]; then
                # Git Bash genelde unzip ile gelir ancak yoksa kurulur
                winget.exe install -e --id GNU.Unzip --accept-source-agreements --accept-package-agreements --silent
            elif [ "$PACKAGE_NAME" = "maven" ]; then
                winget.exe install -e --id Apache.Maven --accept-source-agreements --accept-package-agreements --silent
            elif [ "$PACKAGE_NAME" = "nodejs" ]; then
                winget.exe install -e --id OpenJS.NodeJS --accept-source-agreements --accept-package-agreements --silent
            elif [ "$PACKAGE_NAME" = "git" ]; then
                winget.exe install -e --id Git.Git --accept-source-agreements --accept-package-agreements --silent
            else
                winget.exe install "$PACKAGE_NAME" --accept-source-agreements --accept-package-agreements --silent
            fi
        else
            echo "❌ Windows'ta 'winget' bulunamadı. Lütfen '$PACKAGE_NAME' aracını manuel kurun."
            exit 1
        fi
    else
        echo "❌ Desteklenmeyen işletim sistemi."
        exit 1
    fi
}

check_and_install_unzip() {
    if ! command -v unzip &> /dev/null; then
        echo "⚠️  'unzip' paketi bulunamadı. Kuruluyor..."
        install_system_package "unzip"
    else
        echo "✅ 'unzip' zaten kurulu."
    fi
}

check_and_install_jq() {
    if ! command -v jq &> /dev/null; then
        echo "⚠️  'jq' paketi bulunamadı. Kuruluyor..."
        install_system_package "jq"
    else
        echo "✅ 'jq' zaten kurulu."
    fi
}

check_and_install_maven() {
    if ! command -v mvn &> /dev/null; then
        echo "⚠️  'mvn' bulunamadı. Kuruluyor..."
        install_system_package "maven"
    else
        echo "✅ 'mvn' zaten kurulu."
    fi
}

check_and_install_node() {
    if ! command -v node &> /dev/null; then
        echo "⚠️  'node' bulunamadı. Kuruluyor..."
        install_system_package "nodejs"
    else
        echo "✅ 'node' zaten kurulu ($(node -v))."
    fi
}

check_and_install_npm() {
    if ! command -v npm &> /dev/null; then
        echo "⚠️  'npm' bulunamadı. Kuruluyor..."
        install_system_package "npm"
    else
        echo "✅ 'npm' zaten kurulu ($(npm -v))."
    fi
}

check_and_install_git() {
    if ! command -v git &> /dev/null; then
        echo "⚠️  'git' bulunamadı. Kuruluyor..."
        install_system_package "git"
    else
        echo "✅ 'git' zaten kurulu ($(git --version))."
    fi
}

# --- UYGULAMA REPO'LARINI KLONLAMA METODU ---
# 5 uygulama repo'sunu (account-manager, conference-manager,
# notification-manager, conference-web-api, conference-web-app) crafter-infra
# ile aynı üst dizine (kardeş dizin olarak) klonlar. Klasör/repo zaten
# mevcutsa yeniden klonlamaz (idempotent), böylece betik her çalıştırıldığında
# güvenle tekrar tetiklenebilir.
clone_application_repositories() {
    check_and_install_git

    local SCRIPT_DIR
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local PARENT_DIR="${SCRIPT_DIR}/.."
    local GIT_ORG="bycrafter"

    echo "📥 Uygulama repo'ları '${PARENT_DIR}' dizinine klonlanıyor..."

    local REPOSITORIES=("account-manager" "conference-manager" "notification-manager" "conference-web-api" "conference-web-app")
    for repo in "${REPOSITORIES[@]}"; do
        local REPO_DIR="${PARENT_DIR}/${repo}"
        if [ -d "$REPO_DIR/.git" ]; then
            echo "✅ '${repo}' zaten '${REPO_DIR}' dizininde mevcut, klonlama atlanıyor."
        else
            echo "⬇️  '${repo}' klonlanıyor..."
            git clone "https://github.com/${GIT_ORG}/${repo}.git" "$REPO_DIR"
        fi
    done

    echo "✅ 5 uygulama repo'su da hazır."
}

# --- AWS CLI KURULUM METODU (Evrensel) ---
check_and_install_aws_cli() {
    if ! command -v aws &> /dev/null; then
        echo "⚠️  AWS CLI bulunamadı! Kuruluyor..."
        local OS
        OS=$(detect_os)

        if [ "$OS" = "Mac" ]; then
            brew install awscli
        elif [ "$OS" = "Linux" ]; then
            local TEMP_DIR
            TEMP_DIR=$(mktemp -d)
            cd "$TEMP_DIR"
            curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
            unzip -q awscliv2.zip
            sudo ./aws/install --update
            cd - > /dev/null
            rm -rf "$TEMP_DIR"
        elif [ "$OS" = "Windows" ]; then
            echo "🪟 Windows için resmi AWS CLI MSI paketi indirilip kuruluyor (Sessiz kurulum)..."
            local TEMP_DIR
            TEMP_DIR=$(mktemp -d)
            cd "$TEMP_DIR"

            # Resmi Windows MSI installer'ını indir
            curl -s "https://awscli.amazonaws.com/AWSCLIV2.msi" -o "AWSCLIV2.msi"

            # Windows'un yerleşik msiexec aracı ile arka planda sessizce kur (/qn)
            msiexec.exe /i AWSCLIV2.msi /qn /norestart

            cd - > /dev/null
            rm -rf "$TEMP_DIR"
            echo "⚠️  AWS CLI başarıyla kuruldu. Değişikliklerin terminale yansıması için terminali kapatıp açmanız veya yeni bir sekme başlatmanız gerekebilir!"
        else
            echo "❌ Desteklenmeyen işletim sistemi."
            exit 1
        fi
    else
        echo "✅ AWS CLI zaten kurulu."
    fi
}

verify_aws_credentials() {
    echo "🔑 AWS Kimliği doğrulanıyor..."
    if ! aws sts get-caller-identity &> /dev/null; then
        echo "❌ AWS Kimlik doğrulama hatası!"
        echo "Lütfen terminalde 'aws configure' komutunu çalıştırarak Access Key ve Secret Key değerlerinizi girin."
        exit 1
    fi
    echo "✅ AWS Kimlik doğrulaması başarılı."
}

fetch_secrets_to_environment() {
    echo "🔍 AWS Secrets Manager'dan şifreler çekiliyor..."
    local AWS_REGION="eu-central-1"

    # Fetch account-manager secrets
    local ACCOUNT_SECRET_ID="test/bycrafter/account-manager"
    local ACCOUNT_SECRET_JSON
    ACCOUNT_SECRET_JSON=$(aws secretsmanager get-secret-value --secret-id "$ACCOUNT_SECRET_ID" --region "$AWS_REGION" --query SecretString --output text)

    echo "ACCOUNT DATA: " $ACCOUNT_SECRET_JSON

    export ACCOUNT_POSTGRES_USER=$(echo "$ACCOUNT_SECRET_JSON" | jq -r '.postgres_username')
    export ACCOUNT_POSTGRES_PASSWORD=$(echo "$ACCOUNT_SECRET_JSON" | jq -r '.postgres_password')
    export REDIS_PASSWORD=$(echo "$ACCOUNT_SECRET_JSON" | jq -r '.redis_password')
    export REDIS_USERNAME=$(echo "$ACCOUNT_SECRET_JSON" | jq -r '.redis_username')

    # Fetch conference-manager secrets
    local CONFERENCE_SECRET_ID="test/bycrafter/conference-manager"
    local CONFERENCE_SECRET_JSON
    CONFERENCE_SECRET_JSON=$(aws secretsmanager get-secret-value --secret-id "$CONFERENCE_SECRET_ID" --region "$AWS_REGION" --query SecretString --output text)

    echo "CONFERENCE DATA: " $CONFERENCE_SECRET_JSON

    export CONFERENCE_POSTGRES_USER=$(echo "$CONFERENCE_SECRET_JSON" | jq -r '.postgres_username')
    export CONFERENCE_POSTGRES_PASSWORD=$(echo "$CONFERENCE_SECRET_JSON" | jq -r '.postgres_password')
    export MASTER_ENCRYPTION_KEY=$(echo "$CONFERENCE_SECRET_JSON" | jq -r '.master_encryption_key')

    # Fetch notification-manager secrets
    local NOTIFICATION_SECRET_ID="test/bycrafter/notification-manager"
    local NOTIFICATION_SECRET_JSON
    NOTIFICATION_SECRET_JSON=$(aws secretsmanager get-secret-value --secret-id "$NOTIFICATION_SECRET_ID" --region "$AWS_REGION" --query SecretString --output text)

    echo "NOTIFICATION DATA: " $NOTIFICATION_SECRET_JSON

    export MONGO_INITDB_USERNAME=$(echo "$NOTIFICATION_SECRET_JSON" | jq -r '.mongo_username')
    export MONGO_INITDB_PASSWORD=$(echo "$NOTIFICATION_SECRET_JSON" | jq -r '.mongo_password')
    export SENDER_EMAIL=$(echo "$NOTIFICATION_SECRET_JSON" | jq -r '.sender_email')
    export SENDER_EMAIL_APP_PASSWORD=$(echo "$NOTIFICATION_SECRET_JSON" | jq -r '.sender_email_app_password')
}

down_docker_infrastructure() {
    echo "⬇️  Mevcut Docker Compose servisleri kapatılıyor..."

    local DOCKER_CMD
    if docker compose version &> /dev/null; then
        DOCKER_CMD="docker compose"
    elif command -v docker-compose &> /dev/null; then
        DOCKER_CMD="docker-compose"
    else
        echo "❌ Docker Compose bulunamadı! Lütfen Docker Desktop yükleyin."
        exit 1
    fi

    $DOCKER_CMD down -v || true

    # Force remove any remaining containers
    local CONTAINERS=("account-postgres" "conference-postgres" "redis" "kafka" "notification-mongodb" "account-manager" "conference-manager" "notification-manager" "conference-web-api" "conference-web-app")
    for container in "${CONTAINERS[@]}"; do
        if docker ps -a --format '{{.Names}}' | grep -q "^${container}$"; then
            echo "Removing container: $container"
            docker rm -f "$container" || true
        fi
    done

    # NOT: "$DOCKER_CMD down -v" sadece named volume'ları siler, ancak
    # notification-mongodb servisi için host'a bind-mount edilen
    # ./.docker/mongo-data dizinini SİLMEZ. Bu dizin bir önceki çalıştırmadan
    # (örn. hatalı/eksik init) dolu kalırsa, Mongo /data/db boş olmadığı için
    # docker-entrypoint-initdb.d altındaki mongo-init.sh script'ini BİR DAHA
    # ÇALIŞTIRMAZ ve notification-manager app kullanıcısı asla oluşturulmaz.
    # Bu durumda uygulama var olmayan bir kullanıcıyla bağlanmaya çalışır ve
    # driver, kullanıcıyı bulamadığı için SCRAM-SHA-1'e fallback yapar:
    # "MongoSecurityException: Exception authenticating MongoCredential{
    # mechanism=SCRAM-SHA-1, ...}". Bunu önlemek için her altyapı yeniden
    # başlatmasında bu dizini temizleyip Mongo'nun init script'lerini
    # sıfırdan çalıştırmasını garanti ediyoruz.
    local SCRIPT_DIR
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local MONGO_DATA_DIR="${SCRIPT_DIR}/.docker/mongo-data"
    if [ -d "$MONGO_DATA_DIR" ]; then
        echo "🗑️  Eski Mongo veri dizini siliniyor (init script'lerinin yeniden çalışabilmesi için): $MONGO_DATA_DIR"
        # Mongo container root olarak çalıştığından dosyalar root sahipliğinde
        # olabilir; normal rm başarısız olursa sudo ile tekrar deneriz.
        rm -rf "$MONGO_DATA_DIR" 2>/dev/null || sudo rm -rf "$MONGO_DATA_DIR"
    fi

    echo "✅ Docker servisleri kapatıldı."
}

build_java_application_images() {
    echo "🏗️  Java uygulamalarının (account-manager, conference-manager, notification-manager) Docker image'ları build ediliyor..."

    local DOCKER_CMD
    if docker compose version &> /dev/null; then
        DOCKER_CMD="docker compose"
    elif command -v docker-compose &> /dev/null; then
        DOCKER_CMD="docker-compose"
    else
        echo "❌ Docker Compose bulunamadı! Lütfen Docker Desktop yükleyin."
        exit 1
    fi

    local SCRIPT_DIR
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    # account-manager, conference-manager ve notification-manager'ın
    # Dockerfile'ları runtime-only'dir (kaynak kodu container içinde
    # derlemez); dolayısıyla "docker compose build" öncesinde ilgili
    # repo'nun jar'ının host üzerinde üretilmiş olması gerekir.
    local JAVA_SERVICES=("account-manager" "conference-manager" "notification-manager")
    local NEEDS_MVNW=false
    for service in "${JAVA_SERVICES[@]}"; do
        if [ ! -x "${SCRIPT_DIR}/../${service}/mvnw" ]; then
            NEEDS_MVNW=true
            break
        fi
    done
    # mvnw wrapper'ı olmayan servisler sistemdeki 'mvn' komutuna ihtiyaç
    # duyar; bu yüzden gerekiyorsa build'den önce Maven kurulumunu garantiye alıyoruz.
    if [ "$NEEDS_MVNW" = true ]; then
        check_and_install_maven
    fi

    for service in "${JAVA_SERVICES[@]}"; do
        local SERVICE_DIR="${SCRIPT_DIR}/../${service}"
        if [ ! -d "$SERVICE_DIR" ]; then
            echo "⚠️  ${SERVICE_DIR} bulunamadı, ${service} için jar build adımı atlanıyor."
            continue
        fi

        echo "📦 ${service} jar'ı build ediliyor..."
        pushd "$SERVICE_DIR" > /dev/null
        if [ -x "./mvnw" ]; then
            ./mvnw -pl "${service}-app" -am package -DskipTests
        else
            mvn -pl "${service}-app" -am package -DskipTests
        fi
        popd > /dev/null
    done

    echo "🐳 account-manager, conference-manager ve notification-manager image'ları build ediliyor..."
    $DOCKER_CMD build "${JAVA_SERVICES[@]}"
    echo "✅ Java uygulama image'ları başarıyla build edildi."
}

build_node_application_images() {
    echo "🏗️  Node tabanlı uygulamaların (conference-web-api, conference-web-app) Docker image'ları build ediliyor..."

    local DOCKER_CMD
    if docker compose version &> /dev/null; then
        DOCKER_CMD="docker compose"
    elif command -v docker-compose &> /dev/null; then
        DOCKER_CMD="docker-compose"
    else
        echo "❌ Docker Compose bulunamadı! Lütfen Docker Desktop yükleyin."
        exit 1
    fi

    local NODE_SERVICES=("conference-web-api" "conference-web-app")

    echo "🐳 conference-web-api ve conference-web-app image'ları build ediliyor..."
    $DOCKER_CMD build "${NODE_SERVICES[@]}"
    echo "✅ Node uygulama image'ları başarıyla build edildi."
}

start_docker_infrastructure() {
    echo "🚀 Docker Compose ayağa kaldırılıyor..."

    local DOCKER_CMD
    if docker compose version &> /dev/null; then
        DOCKER_CMD="docker compose"
    elif command -v docker-compose &> /dev/null; then
        DOCKER_CMD="docker-compose"
    else
        echo "❌ Docker Compose bulunamadı! Lütfen Docker Desktop yükleyin."
        exit 1
    fi

    $DOCKER_CMD up -d
    echo "🎉 Tüm YACS altyapısı başarıyla başlatıldı!"
}