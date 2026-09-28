#!/usr/bin/env bash
# Parte 5: ejecutar DENTRO de la instancia EC2 (Amazon Linux 2023).
#   1ª vez:  bash ec2-deploy.sh install   -> instala Docker; luego salir y reconectar por SSH
#   2ª vez:  bash ec2-deploy.sh run       -> despliega la imagen y guarda evidencia en ~/part5-ec2.txt
set -euo pipefail
IMAGE=0x0cbsx/virtualization-lab:1.0

case "${1:-}" in
  install)
    sudo yum update -y
    sudo yum install -y docker
    sudo service docker start
    sudo usermod -a -G docker ec2-user
    echo "Listo. Cierra la sesión SSH, vuelve a conectarte y ejecuta: bash ec2-deploy.sh run"
    ;;
  run)
    run() { echo "\$ $*"; "$@" 2>&1; echo; }
    docker rm -f virtualization-lab >/dev/null 2>&1 || true
    {
      run cat /etc/os-release
      run docker --version
      run docker pull "$IMAGE"
      run docker run -d --name virtualization-lab --restart unless-stopped -e PORT=6000 -p 8080:6000 "$IMAGE"
      sleep 10
      run docker ps
      run docker logs virtualization-lab
      run curl -s "http://localhost:8080/greeting?name=AWS"
      TOKEN=$(curl -s -X PUT http://169.254.169.254/latest/api/token -H "X-aws-ec2-metadata-token-ttl-seconds: 60")
      echo "Public DNS: $(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/public-hostname)"
    } | tee ~/part5-ec2.txt
    ;;
  *) echo "Uso: $0 install|run"; exit 1 ;;
esac
