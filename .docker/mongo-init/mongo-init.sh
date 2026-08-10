#!/bin/bash
# Bu script, MongoDB container'i ilk defa olusturuldugunda (yani /data/db
# boskken) mongo image'i tarafindan otomatik olarak calistirilir
# (docker-entrypoint-initdb.d mekanizmasi).
#
# Amac: notification-manager uygulamasinin kullanacagi normal (non-root)
# kullaniciyi, MONGO_INITDB_DATABASE (notification_db) uzerinde olusturmak.
# Root kullanici (MONGO_INITDB_ROOT_USERNAME/PASSWORD) sadece bu script'in
# calisabilmesi icin kullanilir, uygulama bu kullaniciyi KULLANMAZ.
set -e

mongosh <<MONGOEOF
db = db.getSiblingDB("${MONGO_INITDB_DATABASE}")

db.createUser({
  user: "${MONGO_APP_USERNAME}",
  pwd: "${MONGO_APP_PASSWORD}",
  roles: [
    { role: "readWrite", db: "${MONGO_INITDB_DATABASE}" }
  ]
})
MONGOEOF
