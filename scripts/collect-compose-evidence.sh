#!/usr/bin/env bash
# Parte 3: levanta web + MongoDB con Docker Compose y guarda la salida real como evidencia.
# Uso (desde la raíz del repo, con Docker Desktop corriendo):  ./scripts/collect-compose-evidence.sh
set -euo pipefail
cd "$(dirname "$0")/.."
OUT=docs/evidence/part3-compose.txt

run() { echo "\$ $*"; "$@" 2>&1; echo; }

if command -v mvn >/dev/null; then
  mvn -q clean package -DskipTests
else  # sin Maven local: compilar dentro de un contenedor de Maven
  docker run --rm -u "$(id -u):$(id -g)" -e MAVEN_CONFIG=/tmp/.m2 -v "$PWD":/src -w /src \
    maven:3.9-amazoncorretto-21 mvn -q -Dmaven.repo.local=/tmp/.m2 clean package -DskipTests
fi
docker compose up -d --build
sleep 15

{
  run docker compose ps
  run docker compose logs web
  run docker compose logs --tail 20 db
  run curl -s "http://localhost:8087/greeting?name=Compose"
  echo
  echo '$ docker compose exec db mongosh --quiet --eval "<show dbs; use workshop; insertOne; find>"'
  docker compose exec -T db mongosh --quiet --eval '
    db = db.getSiblingDB("workshop");
    printjson(db.messages.insertOne({ message: "Hello from Docker Compose" }));
    printjson(db.messages.find().toArray());
    printjson(db.adminCommand({ listDatabases: 1 }).databases.map(d => d.name));'
  echo
  run docker volume ls
  run docker compose down
  echo "# Los volúmenes sobreviven a 'docker compose down':"
  run docker volume ls
} | tee "$OUT"
echo "Evidencia guardada en $OUT"
