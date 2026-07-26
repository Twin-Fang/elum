FROM eclipse-temurin:21-jre-alpine

# 작업 디렉토리 설정
WORKDIR /app

# curl 설치
RUN apk add --no-cache curl

# 빌드된 JAR 파일을 복사
COPY build/libs/elum-server-*.jar /app.jar

# 애플리케이션 실행 (기본 Spring Boot 설정)
ENTRYPOINT ["java", "-jar", "/app.jar"]

# Spring Boot 서버 포트 노출
EXPOSE 8080

# Docker Swarm 헬스체크 — Actuator 의존성이 없어 /actuator/health는 항상 404였다.
# 서버가 직접 제공하는 /healthz(HealthController)로 검사한다.
HEALTHCHECK --interval=30s --timeout=5s --start-period=120s --retries=5 \
CMD curl -f http://localhost:8080/healthz || exit 1
