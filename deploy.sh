#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

APP=sdust
URL="http://localhost:8080/$APP/"

if [[ -z "${TOMCAT_HOME:-}" ]]; then
    if command -v brew >/dev/null 2>&1 && brew --prefix tomcat >/dev/null 2>&1; then
        TOMCAT_HOME="$(brew --prefix tomcat)/libexec"
    else
        echo "Set TOMCAT_HOME to your Tomcat folder (the one containing bin/ and webapps/)." >&2
        exit 1
    fi
fi
WEBAPPS="$TOMCAT_HOME/webapps"

echo "==> Building WAR with Maven"
mvn -q clean package -Dproject.build.outputTimestamp="$(date +%Y-%m-%dT%H:%M:%SZ)"

echo "==> Deploying to $WEBAPPS"
rm -rf "${WEBAPPS:?}/$APP" "$WEBAPPS/$APP.war"
cp "target/$APP.war" "$WEBAPPS/"

tomcat_running() { curl -s -o /dev/null --max-time 2 "http://localhost:8080/"; }

if tomcat_running; then
    echo "==> Tomcat is already running; it will hot-deploy the new WAR"
else
    echo "==> Starting Tomcat"
    "$TOMCAT_HOME/bin/catalina.sh" start
fi

echo -n "==> Waiting for the app"
for _ in $(seq 1 60); do
    [[ -d "$WEBAPPS/$APP/WEB-INF" ]] && break
    echo -n "."
    sleep 1
done
for _ in $(seq 1 60); do
    code=$(curl -s -L -o /dev/null -w '%{http_code}' --max-time 3 "$URL" || true)
    if [[ "$code" == "200" ]]; then
        echo
        echo "==> SDUST website is up: $URL"
        exit 0
    fi
    echo -n "."
    sleep 1
done
echo
echo "The app did not answer with HTTP 200 yet. Check $TOMCAT_HOME/logs/ (catalina.*.log, localhost.*.log)." >&2
exit 1
