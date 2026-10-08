FROM maven:3.9.11-eclipse-temurin-17 AS build
WORKDIR /app
COPY pom.xml .
RUN mvn -q -B dependency:go-offline
COPY src src
RUN mvn -q -B package -DskipTests

FROM eclipse-temurin:17-jre
WORKDIR /app
RUN useradd --system --create-home --home-dir /app app
COPY --from=build /app/target/*.jar app.jar
RUN mkdir -p /app/uploads && chown -R app:app /app
USER app
EXPOSE 8080
ENV SERVER_ADDRESS=0.0.0.0
ENV PHOTO_DIR=/app/uploads
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
