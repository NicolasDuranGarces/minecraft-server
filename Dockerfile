FROM eclipse-temurin:21-jdk-jammy

ARG PAPER_VERSION=1.21.8
ARG PAPER_BUILD=latest

ENV PAPER_VERSION=${PAPER_VERSION} \
    PAPER_BUILD=${PAPER_BUILD} \
    PAPER_JAR=/opt/paper/paperclip.jar \
    SKINSRESTORER_VERSION=15.9.0

RUN apt-get update \
    && apt-get install -y --no-install-recommends curl python3 rsync unzip \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /opt/paper

RUN set -eux; \
    VERSION="$PAPER_VERSION"; \
    BUILD_INPUT="$PAPER_BUILD"; \
    if [ "$BUILD_INPUT" = "latest" ]; then \
      BUILD=$(curl -fsSL "https://api.papermc.io/v2/projects/paper/versions/${VERSION}" | python3 -c "import sys,json;data=json.load(sys.stdin);print(data['builds'][-1])"); \
    else \
      BUILD=$BUILD_INPUT; \
    fi; \
    curl -fsSL "https://api.papermc.io/v2/projects/paper/versions/${VERSION}/builds/${BUILD}/downloads/paper-${VERSION}-${BUILD}.jar" -o paperclip.jar; \
    ln -sf paperclip.jar server.jar; \
    echo "$BUILD" > /opt/paper/.paper-build

COPY scripts/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

VOLUME ["/data"]
EXPOSE 25565 25575

ENV JVM_FLAGS="-Xms2G -Xmx2G" \
    EULA=false \
    MC_MAX_PLAYERS=20 \
    MC_DIFFICULTY=normal

ENTRYPOINT ["/entrypoint.sh"]
