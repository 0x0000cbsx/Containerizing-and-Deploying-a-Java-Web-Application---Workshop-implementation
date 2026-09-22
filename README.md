# Contenerización y despliegue de una aplicación web Java

Workshop de virtualización: se construye una pequeña aplicación web con Spring Boot, se empaqueta como imagen Docker, se ejecuta en contenedores aislados en local, se publica en Docker Hub y se despliega en una instancia EC2 de AWS.

## Stack tecnológico

- Java 21 LTS
- Maven 3.9+
- Spring Boot 4.1.1
- Docker / Docker Compose v2
- Docker Hub
- Amazon Linux 2023 sobre AWS EC2
- Imagen oficial `amazoncorretto:21`

## Estructura del repositorio

```
├── pom.xml
├── Dockerfile
├── compose.yaml
├── src/main/java/co/edu/escuelaing/virtualizationlab/
│   ├── RestServiceApplication.java   # punto de entrada, lee PORT del entorno
│   └── HelloRestController.java      # GET /greeting?name=
├── src/test/java/...                 # prueba unitaria del controlador
└── docs/evidence/                    # evidencia (capturas y logs) citada en este README
```

## Parte 1 — Aplicación web

Controlador REST con un único endpoint:

```java
@GetMapping("/greeting")
public String greeting(@RequestParam(value = "name", defaultValue = "World") String name) {
    return "Hello, " + name + "!";
}
```

El puerto se lee de la variable de entorno `PORT`, con `6000` como valor por defecto:

```java
application.setDefaultProperties(
        Map.of("server.port", System.getenv().getOrDefault("PORT", "6000")));
```

### Construcción y ejecución local

```bash
mvn clean package
java -jar target/virtualization-lab-1.0.0.jar
```

```
http://localhost:6000/greeting?name=Pedro
→ Hello, Pedro!
```

**Evidencia:** [`docs/evidence/part1-local-run.txt`](docs/evidence/part1-local-run.txt)

## Parte 2 — Imagen y contenedores Docker

`Dockerfile`:

```dockerfile
FROM amazoncorretto:21
WORKDIR /app
COPY target/*.jar app.jar
ENV PORT=6000
EXPOSE 6000
ENTRYPOINT ["java", "-jar", "app.jar"]
```

Build y ejecución:

```bash
docker build -t 0x0cbsx/virtualization-lab:1.0 .
docker run -d --name virtualization-lab-1 -e PORT=6000 -p 34000:6000 0x0cbsx/virtualization-lab:1.0
```

### Aislamiento entre contenedores

Se levantaron tres contenedores de la misma imagen, cada uno mapeado a un puerto distinto del host, y cada uno respondió de forma independiente:

```
docker run -d --name virtualization-lab-2 -p 34001:6000 0x0cbsx/virtualization-lab:1.0
docker run -d --name virtualization-lab-3 -p 34002:6000 0x0cbsx/virtualization-lab:1.0

curl http://localhost:34000/greeting?name=Container1 → Hello, Container1!
curl http://localhost:34001/greeting?name=Container2 → Hello, Container2!
curl http://localhost:34002/greeting?name=Container3 → Hello, Container3!
```

**Evidencia:** [`docs/evidence/part2-isolation.txt`](docs/evidence/part2-isolation.txt) (salida real de `docker images`, `docker ps` y las tres peticiones `curl`).

## Parte 3 — Docker Compose

`compose.yaml`:

```yaml
services:
  web:
    build: .
    container_name: virtualization-web
    environment:
      PORT: 6000
    ports:
      - "8087:6000"
```

```bash
docker compose up -d --build
curl http://localhost:8087/greeting?name=Compose
→ Hello, Compose!
```

**Evidencia:** [`docs/evidence/part3-compose.txt`](docs/evidence/part3-compose.txt) (`docker compose ps`, logs de arranque de Spring Boot y la respuesta del endpoint).

## Parte 4 — Publicación en Docker Hub

Repositorio público: **https://hub.docker.com/r/0x0cbsx/virtualization-lab**

```bash
docker tag 0x0cbsx/virtualization-lab:1.0 0x0cbsx/virtualization-lab:latest
docker push 0x0cbsx/virtualization-lab:1.0
docker push 0x0cbsx/virtualization-lab:latest
```

Ambos tags (`1.0` y `latest`) quedaron publicados y son visibles sin autenticación (repositorio público).

**Evidencia:** [`docs/evidence/part4-dockerhub-push.txt`](docs/evidence/part4-dockerhub-push.txt) y captura [`docs/evidence/dockerhub-repository.jpg`](docs/evidence/dockerhub-repository.jpg).

## Parte 5 — Despliegue en AWS EC2

- **Instancia:** `i-0827491fa729291d0` — Amazon Linux 2023, `t3.micro`, región `us-east-1`
- **IP pública:** `52.91.102.91`
- **DNS público:** `ec2-52-91-102-91.compute-1.amazonaws.com`
- **Security group (`launch-wizard-1`):**
  - SSH (22/TCP) restringido a la IP pública del operador (`/32`).
  - TCP 8080 abierto a `0.0.0.0/0` (necesario para exponer la URL pública de evaluación).
  - Ningún otro puerto expuesto.

**Evidencia:** [`docs/evidence/aws-ec2-instance-running.jpg`](docs/evidence/aws-ec2-instance-running.jpg) (consola EC2, instancia `En ejecución`).

> **Estado:** la instancia está creada, en ejecución y con la red/seguridad configurada según el enunciado. La instalación de Docker y el `docker run` de la imagen publicada dentro de la instancia (y por tanto la URL pública final `http://<dns-publico>:8080/greeting`) quedan **pendientes de completar** — el acceso SSH inicial tardó en habilitarse (los *status checks* de la instancia permanecieron en "Inicializando" un tiempo prolongado, un comportamiento conocido en AWS Academy Learner Labs). Esta sección se actualizará con la URL pública final y la evidencia de `docker ps` / `docker logs` dentro de la instancia en el siguiente commit.

Comandos que se ejecutarán dentro de la instancia para completar el despliegue:

```bash
sudo yum update -y
sudo yum install -y docker
sudo service docker start
sudo usermod -a -G docker ec2-user

docker pull 0x0cbsx/virtualization-lab:1.0
docker run -d --name virtualization-lab --restart unless-stopped \
  -e PORT=6000 -p 8080:6000 0x0cbsx/virtualization-lab:1.0
```

## Parte 6 — Modelo de despliegue y análisis de costos

### Arquitectura del despliegue

```
Cliente
  ↓ petición HTTP
Instancia virtual EC2
  ↓
Docker Engine
  ↓
Contenedor de la aplicación web Java (Spring Boot)
```

| Capa | Responsabilidad |
|---|---|
| Instancia EC2 | Cómputo, memoria, almacenamiento y red aislados, facturados por hora/segundo. |
| Contenedor Docker | Entorno de ejecución portable que empaqueta la aplicación y su runtime (JRE 21). |
| Aplicación Java | Recibe peticiones HTTP y expone la lógica de negocio (`/greeting`). |
| Security group | Controla qué tráfico entrante puede llegar a la instancia. |

### Supuestos por escenario

Los tres escenarios usan la misma región (**US East, N. Virginia**), almacenamiento EBS `gp3` de **8 GiB** (igual al volumen raíz real desplegado), tarifa **On-Demand** (sin compromiso de reserva, apropiado para un despliegue de laboratorio de corta duración) y ejecución **continua** (730 h/mes) porque el servicio se expone como una API disponible permanentemente, no por horario. No se requiere alta disponibilidad en ninguno de los tres casos: es una sola instancia sin balanceador ni auto scaling.

| Escenario | Peticiones/mes | Tipo de instancia | Tamaño resp. promedio | Transferencia saliente estimada |
|---|---|---|---|---|
| Pequeño | 10.000 | 1× `t3.micro` | ~0,5 KB | ~5 MB/mes (redondeado a 1 GB para el cálculo) |
| Mediano | 100.000 | 1× `t3.micro` | ~0,5 KB | ~50 MB/mes (redondeado a 2 GB) |
| Grande | 1.000.000 | 1× `t3.small` (más margen de CPU/RAM) | ~0,5 KB | ~500 MB/mes (redondeado a 5 GB) |

*(La respuesta del endpoint `/greeting` es un texto de pocos bytes; el redondeo hacia arriba en la transferencia de datos es intencional, para no subestimar el costo.)*

### Estimación de costos (AWS Pricing Calculator)

Estimación pública generada con la calculadora oficial: **https://calculator.aws/#/estimate?id=079d0f7b3b9793b84cf8e19e74e5eb81dbe9b486**

**Evidencia:** [`docs/evidence/aws-pricing-calculator-estimate.jpg`](docs/evidence/aws-pricing-calculator-estimate.jpg)

| Escenario | Peticiones/mes | Costo mensual de infraestructura | Costo estimado por petición | Principales generadores de costo |
|---|---|---|---|---|
| Pequeño | 10.000 | USD 8,32 | USD 0,000832 | Horas de EC2 + almacenamiento EBS (la transferencia de datos es prácticamente nula) |
| Mediano | 100.000 | USD 8,41 | USD 0,0000841 | Horas de EC2 + almacenamiento; la transferencia sigue siendo marginal |
| Grande | 1.000.000 | USD 16,27 | USD 0,00001627 | Instancia más grande (`t3.small`) para tener margen de CPU/RAM; transferencia de datos empieza a ser perceptible |

Costo por petición = costo mensual de infraestructura ÷ peticiones del mes.

### Discusión arquitectónica

**¿Por qué un despliegue basado en EC2 tiene un costo base mensual aunque reciba pocas peticiones?**
Porque se paga por el *cómputo reservado* (la instancia encendida) y por el *almacenamiento aprovisionado* (el volumen EBS), no por petición atendida. Una instancia `t3.micro` cuesta lo mismo esté recibiendo 10 o 10.000 peticiones ese mes, porque AWS factura por tiempo de actividad de la VM, no por uso real de CPU.

**¿En qué nivel de carga el costo fijo deja de ser relevante por petición?**
A partir de decenas de miles de peticiones/mes el costo por petición ya cae a fracciones de centavo, y en el escenario grande (1.000.000) el costo por petición es casi 100 veces menor que en el pequeño. El costo fijo "se diluye" mientras el tráfico crece; a partir de cierto punto, sin embargo, empieza a dominar de nuevo el tamaño de la instancia y la transferencia de datos, no el costo base.

**¿Qué obligaría a pasar de una instancia EC2 a varias?**
Que una sola instancia no pueda sostener la concurrencia o la latencia requerida (CPU/RAM agotados, cola de conexiones saturada), que se necesite tolerancia a fallos (si la instancia única se cae, el servicio completo cae) o que se necesite desplegar en múltiples zonas de disponibilidad/regiones para reducir latencia geográfica.

**¿Qué otros servicios necesitaría un despliegue en producción?**
Un balanceador de carga (Application Load Balancer) frente a varias instancias en un Auto Scaling Group, una base de datos administrada (RDS) en vez de almacenamiento local, un registro de imágenes privado (Amazon ECR) en vez de Docker Hub público, monitoreo y alarmas (CloudWatch), backups automatizados y, probablemente, un WAF/CDN (CloudFront) delante del balanceador.

**¿Sería más económico un despliegue serverless para el escenario pequeño?**
Sí, muy probablemente. Con 10.000 peticiones al mes el tráfico es extremadamente bajo y esporádico: una función Lambda (facturada por invocación y milisegundos de ejecución, con una capa gratuita generosa) no tendría el costo fijo de una instancia encendida 24/7. La ventaja de EC2 aparece cuando la carga es sostenida y predecible (como en el escenario grande), donde pagar por tiempo de actividad termina siendo más barato que pagar por invocación; para tráfico bajo e irregular, pagar solo por lo que efectivamente se ejecuta (serverless) es más eficiente.

### Conclusión

Para los tres escenarios evaluados, el costo de infraestructura EC2 se mantiene entre 8 y 16 dólares al mes, dominado por el costo fijo de la instancia encendida y no por el volumen de tráfico. EC2 es una opción razonable y sencilla para el escenario grande (carga sostenida, donde el costo por petición ya es marginal), pero para el escenario pequeño un enfoque serverless probablemente sería más costo-eficiente al evitar pagar por una instancia inactiva la mayor parte del tiempo. Dado que este workshop es una prueba de concepto de virtualización y no un servicio productivo, EC2 con una sola instancia `t3.micro` es apropiado por su simplicidad operativa, aunque no sería la elección final para una carga real de producción sin agregar balanceo, escalado automático y alta disponibilidad.
