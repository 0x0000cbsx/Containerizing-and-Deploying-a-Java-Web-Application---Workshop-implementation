FROM amazoncorretto:21

WORKDIR /app

COPY target/*.jar app.jar

ENV PORT=6000

EXPOSE 6000

ENTRYPOINT ["java", "-jar", "app.jar"]
