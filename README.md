# Verdaccio on Railway

Start script for the Verdaccio Railway template. The template runs the official
`verdaccio/verdaccio:7.1.0` image (pinned by digest) and inlines `start.sh` in the
service's start command as a gzip+base64 blob, so nothing is built from this repo.

What `start.sh` does on every boot:

1. Writes `/verdaccio/conf/railway.yaml`: storage and htpasswd on the volume at
   `/verdaccio/storage`, sign-up closed (`max_users: -1`), read and publish need a
   login (`$authenticated`), npmjs.org as the uplink.
2. Creates the admin user in htpasswd from `VERDACCIO_ADMIN_USERNAME` (default `admin`)
   and `VERDACCIO_ADMIN_PASSWORD` (bcrypt). If the password variable changes, the
   admin password is updated on the next deploy.
3. Gives the volume to the image's `verdaccio` user (uid 10001) and drops root,
   then starts Verdaccio on `$PORT`.

Optional variables: `VERDACCIO_ACCESS` (default `$authenticated`; set `$all` for
anonymous installs), `VERDACCIO_PUBLISH` (default `$authenticated`),
`VERDACCIO_MAX_USERS` (default `-1`, sign-up closed), `VERDACCIO_TITLE`,
`VERDACCIO_LOG_LEVEL`, `VERDACCIO_LOG_FORMAT`.

To regenerate the start command: `gzip -9c start.sh | base64 -w0`, then use
`/bin/sh -c "echo <blob> | base64 -d | gunzip > /tmp/start.sh && exec sh /tmp/start.sh"`.

Verdaccio is MIT-licensed: https://github.com/verdaccio/verdaccio
