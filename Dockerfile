# Normalize artifact name.
ARG ARTIFACT_NAME=app

#
# Build image.
#
FROM eclipse-temurin:11-jdk-alpine as build

LABEL stage=builder

ARG ARTIFACT_NAME

# Install prerequisits for maven installation.
RUN apk add --no-cache \
    curl \
    tar \
    bash \
    procps \
    wget

# Downloading and installing Maven.
# Define a constant with the version of maven you want to install.
ARG MAVEN_VERSION=3.8.6         
ARG MAVEN_WRAPPER_VERSION=${MAVEN_VERSION}
# Define the SHA key to validate the maven download.
ARG SHA=f790857f3b1f90ae8d16281f902c689e4f136ebe584aba45e4b1fa66c80cba826d3e0e52fdd04ed44b4c66f6d3fe3584a057c26dfcac544a60b301e6d0f91c26
# Define the URL where maven can be downloaded from.
ARG BASE_URL=https://apache.osuosl.org/maven/maven-3/${MAVEN_VERSION}/binaries

# Create the directories, download maven, validate the download, install it, remove downloaded file and set links.
RUN mkdir -p /usr/share/maven /usr/share/maven/ref
RUN echo "Downlaoding maven"
RUN curl -fsSL -o /tmp/apache-maven.tar.gz ${BASE_URL}/apache-maven-${MAVEN_VERSION}-bin.tar.gz
RUN echo "Checking download hash"
RUN echo "${SHA}  /tmp/apache-maven.tar.gz" | sha512sum -c -
RUN echo "Unziping maven"
RUN tar -xzf /tmp/apache-maven.tar.gz -C /usr/share/maven --strip-components=1
RUN echo "Cleaning and setting links"
RUN rm -f /tmp/apache-maven.tar.gz
RUN ln -s /usr/share/maven/bin/mvn /usr/bin/mvn

# Copy sources.
WORKDIR /usr/src/app
COPY . .
RUN chmod +x mvnw

# Normalize artifact name.
RUN sed -i "s/<\/build>/\t<finalName>${ARTIFACT_NAME}<\/finalName>\n\t<\/build>/" pom.xml

RUN mkdir .m2
RUN ls -lisa
COPY settings.xml .m2/settings.xml

# Build
RUN mvn wrapper:wrapper -Dmaven=${MAVEN_WRAPPER_VERSION}
RUN ./mvnw clean install -DskipTests


#
# Final image.
#
FROM eclipse-temurin:11-jdk-alpine as final

ARG ARTIFACT_NAME

WORKDIR /usr/src/app

COPY --from=build "/usr/src/app/target/${ARTIFACT_NAME}.jar" app.jar

# Run as non-root.
RUN addgroup -g 1001 -S appuser && adduser -u 1001 -S appuser -G appuser
RUN mkdir logs
RUN chown -R 1001:1001 .
USER 1001

# LABEL env=dev app=api-gw
ENTRYPOINT ["sh", "-c", "java ${JAVA_OPTS} -jar app.jar ${0} ${@}"]
