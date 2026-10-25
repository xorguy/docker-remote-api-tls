FROM docker:29.9.2-cli AS docker
FROM maven:3.9.16-eclipse-temurin-21

COPY --from=docker --chmod=555 /usr/local/bin/docker /usr/local/bin/docker
COPY --from=docker --chmod=555 /usr/local/libexec/docker/cli-plugins/ /root/.docker/cli-plugins

WORKDIR /build
COPY pom.xml .
RUN mvn dependency:go-offline
COPY . .

CMD mvn test
