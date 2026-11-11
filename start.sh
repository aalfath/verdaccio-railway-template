#!/bin/sh
# Verdaccio on Railway: write the config, sync the admin user, start the server.
# Source: https://github.com/aalfath/verdaccio-railway-template
set -eu
STORAGE=/verdaccio/storage
CONF=/verdaccio/conf/railway.yaml
ADMIN_USER="${VERDACCIO_ADMIN_USERNAME:-admin}"
: "${VERDACCIO_ADMIN_PASSWORD:?VERDACCIO_ADMIN_PASSWORD must be set}"
ACCESS="${VERDACCIO_ACCESS:-\$authenticated}"
PUBLISH="${VERDACCIO_PUBLISH:-\$authenticated}"
MAX_USERS="${VERDACCIO_MAX_USERS:--1}"
mkdir -p "$STORAGE/data"

cat > "$CONF" <<EOF
storage: $STORAGE/data
plugins: /verdaccio/plugins
web:
  title: "${VERDACCIO_TITLE:-Verdaccio}"
auth:
  htpasswd:
    file: $STORAGE/htpasswd
    max_users: $MAX_USERS
uplinks:
  npmjs:
    url: https://registry.npmjs.org/
packages:
  '@*/*':
    access: $ACCESS
    publish: $PUBLISH
    unpublish: $PUBLISH
    proxy: npmjs
  '**':
    access: $ACCESS
    publish: $PUBLISH
    unpublish: $PUBLISH
    proxy: npmjs
server:
  keepAliveTimeout: 60
  dotfiles: ignore
middlewares:
  audit:
    enabled: true
log:
  type: stdout
  format: ${VERDACCIO_LOG_FORMAT:-pretty}
  level: ${VERDACCIO_LOG_LEVEL:-http}
EOF

# Create or update the admin in htpasswd from VERDACCIO_ADMIN_PASSWORD (bcrypt).
node -e '
const fs = require("fs");
const bcrypt = require("/usr/local/lib/node_modules/verdaccio/node_modules/bcryptjs");
const [file, user] = process.argv.slice(1);
const pw = process.env.VERDACCIO_ADMIN_PASSWORD;
if (!/^[^:\s]+$/.test(user)) { console.error("invalid VERDACCIO_ADMIN_USERNAME"); process.exit(1); }
const lines = fs.existsSync(file) ? fs.readFileSync(file, "utf8").split("\n").filter(Boolean) : [];
const i = lines.findIndex(l => l.split(":")[0] === user);
if (i >= 0 && bcrypt.compareSync(pw, lines[i].split(":")[1] || "")) { console.log("admin user " + user + " is up to date"); process.exit(0); }
const entry = user + ":" + bcrypt.hashSync(pw, 10) + ":autocreated " + new Date().toISOString();
if (i >= 0) lines[i] = entry; else lines.unshift(entry);
fs.writeFileSync(file, lines.join("\n") + "\n", { mode: 0o600 });
console.log((i >= 0 ? "updated" : "created") + " admin user " + user);
' "$STORAGE/htpasswd" "$ADMIN_USER"

RUN="exec verdaccio --config $CONF --listen http://0.0.0.0:${PORT:-4873}"
if [ "$(id -u)" = 0 ]; then
  # Railway volumes are owned by root: hand storage to the image's verdaccio user, then drop root.
  find "$STORAGE" ! -user 10001 -exec chown 10001:0 {} +
  chown 10001:0 "$CONF"
  exec su -p -s /bin/sh -c "$RUN" verdaccio
fi
eval "$RUN"
