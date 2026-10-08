---
title: "얼쑤 기술 스택 및 배포"
aliases: ["얼쑤 기술 스택"]
service: "얼쑤"
team: "에헤라디야"
type: "architecture"
version: "0.9"
status: "개발·운영 배포 완료 · VM 공유"
created: "2026-09-30"
updated: "2026-10-01"
tags: ["얼쑤", "문서/architecture"]
---

# 기술 스택 및 배포 — 얼쑤

[← 얼쑤 문서 홈](README.md)

## 현재 구성

| 영역 | 실제 구성 | 상태 |
| --- | --- | --- |
| 웹 | Next.js 16·React 19·TypeScript·Lucide, Vercel | main 운영·develop Preview 배포 완료 |
| API | Java 21·Spring Boot 4.1.1·JPA, Docker, Oracle | dev/prod 컨테이너 실행 |
| DB | PostgreSQL 17, 별도 DB VM | 개발/운영 DB·계정 분리, Flyway V1/V2/V3 적용 |
| HTTPS 진입점 | Caddy, sslip.io 호스트 | 인증서·웹 API 연결 확인 |
| 이미지 | 환경별 API 파일 볼륨 | 현재 방식. 20MiB 원본 허용·1600px JPEG 압축·환경별 한도 적용, R2·미사용 파일 정리 미구현 |
| 학교 인증 메일 | 팀 Gmail SMTP STARTTLS·앱 비밀번호 | 서버 SMTP 인증 성공, 실제 학교 메일 수신 검증 대기 |
| 저장소 | TheSoftBelly/eolssu-web, TheSoftBelly/eolssu-api | 비공개, 프론트·백 분리 |
| Gateway·서비스 분리 | 단일 Spring Boot 애플리케이션 | Caddy·Docker DNS HTTP Gateway 구성, 전용 Spring Gateway/마이크로서비스 미구현 |

현재 웹의 요청은 브라우저 → Vercel Next.js `/v1/*` rewrite → Caddy HTTPS → 환경별 Spring Boot → DB VM 내부 5432 순서로 전달된다. Vercel은 화면·같은 출처 API 전달을 담당하고, 인증·권한·데이터 변경은 Spring Boot에서 처리한다. Caddy와 rewrites만으로 별도 업무 정책 Gateway가 구현된 것은 아니다.

## 개발·운영 환경 분리

A1 추가 VM의 용량 부족으로 기존 무료 Micro API/DB VM 두 대를 공유한다. API VM은 내부 [접속 IP 비공개], 공인 [접속 IP 비공개]이며 DB VM은 내부 [접속 IP 비공개], 공인 IP가 없다. 두 VM 모두 RAM 1GB·swap 2GB이고 swap은 RAM 증설을 대체하지 않는다.

| 항목 | 개발 | 운영 |
| --- | --- | --- |
| 웹 | https://eolssu-web-git-develop-thesoftbellys-projects.vercel.app | https://earthuu.vercel.app |
| API | 운영 담당자에게 전달받은 HTTPS 주소 | 운영 담당자에게 전달받은 HTTPS 주소 |
| Spring 프로필 | dev | prod |
| API Docker 프로젝트 | eolssu-dev | eolssu-prod |
| DB | eolssu_dev | eolssu_prod |
| DB 계정 | eolssu | eolssu_prod |
| 미디어 볼륨 | eolssu-dev_media_data | eolssu-prod_media_data |
| API 환경 파일 | /home/ubuntu/eolssu-dev/.env.dev | /home/ubuntu/eolssu-prod/.env.prod |
| Vercel API_ORIGIN 범위 | Preview, develop 브랜치만 | Production |

API 컨테이너·DB·계정·미디어·환경 파일은 분리하지만 VM·Docker 네트워크·Caddy·PostgreSQL 프로세스는 공유한다. 서버 장애와 자원 부족이 양쪽에 영향을 준다. 별도 VM과 네트워크 격리는 향후 자원을 확보한 후 진행한다. 개발 DB를 운영 DB로 복사하지 않았으며 현재 원격 모임 목록이 비어 있는 것은 정상이다.

## 웹과 API 연결

Vercel은 `NEXT_PUBLIC_API_URL=same-origin`과 환경별 `API_ORIGIN`을 사용한다. `API_ORIGIN`은 빌드의 rewrite에 반영되므로 변경 후 새 배포가 필요하다. Production 설정 누락으로 운영 웹의 `/v1` 경로가 404를 반환했던 문제를 주소 설정·재배포로 해결했다.

운영 웹을 경유한 모임 조회와 POSTECH 도메인 판별은 200, 미로그인 회원 조회는 401, 빈 로그인·가입 입력은 400으로 확인했다. 실제 가입 성공이나 이메일 수신 검증을 의미하지 않는다. 학교 인증은 사용자가 운영 웹에서 진행한다.

Caddy는 `deploy/Caddyfile.shared`로 개발·운영 두 호스트를 처리한다. 현재 API VM의 `/home/ubuntu/eolssu-dev/deploy/Caddyfile`에 이 공유 설정이 설치되어 있다. 단일 호스트 설정으로 덮어쓰면 운영 연결이 끊길 수 있다. sslip.io 주소는 공인 IP와 연결되므로 IP가 바뀌면 Caddy·Vercel 주소·인증서 설정도 갱신한다.

## 저장소와 배포 책임

| 저장소 | 포함 범위 |
| --- | --- |
| eolssu-web | 사용자 웹, API 클라이언트, 화면 설정, Next.js rewrite, 웹 검증 워크플로 |
| eolssu-api | 기능별 Java 패키지, DB 마이그레이션, 인증·메일·미디어, Docker/Compose/Caddy, 제품 문서 |

웹 main은 Vercel Production, develop은 Preview로 자동 배포한다. 백엔드 develop GitHub Actions는 테스트와 AMD64 이미지 빌드를 수행한다. 실제 Oracle 배포는 수동이며 SSH 배포 작업은 비활성화다. 관리자 IP만 허용하는 SSH 규칙과 GitHub 호스팅 runner의 동적 IP가 맞지 않아 안전한 별도 접속 경로를 먼저 구성해야 한다.

운영 API는 검증된 f505ced 이미지로 실행한다. 웹은 2160c4a 코드로 Production Ready를 확인했다. 이후 배포 설정·문서 커밋은 실행 이미지 변경과 구분한다. 자세한 배포 식별값은 [12-production-deployment](12-production-deployment.md)를 따른다.

## 네트워크와 비밀 설정

- 공개 포트는 Caddy 80/443. API 8080은 직접 공개하지 않는다.
- SSH는 관리자 접속 IP 및 승인한 API→DB 내부 경로로 제한한다.
- DB 5432는 API 내부 IP [접속 IP 비공개]/32에서만 허용한다.
- 환경 파일은 권한 600, Git 제외. SMTP 앱 비밀번호·DB 비밀번호·SSH 개인키는 문서에 기록하지 않는다.
- 세션 쿠키는 dev/prod에서 Secure·HttpOnly로 사용한다. 개발·운영 DB가 다르므로 회원·세션도 별도다.
- 실제 관리자 권한을 갖춘 대시보드는 미구현이며 인증 없는 로컬 시연 API는 dev/prod에 노출하지 않는다.

## 비용과 다음 단계

현재 별도 서버를 추가하지 않고 기존 무료 자원을 사용한다. 무료 한도·약관·이용량은 계정 콘솔에서 확인해야 하며 비용이 항상 0원이라고 보장하지 않는다. 작은 VM은 실제 동시 사용자 부하를 아직 검증하지 않았다.

- [x] 개발·운영 API 배포, HTTPS·Vercel 연결, DB V1/V2 적용.
- [x] Gmail 설정 적용·SMTP 인증 확인.
- [ ] 실제 학교 메일 수신·코드 입력·프로필·모임 작성·참여 검증.
- [ ] DB·미디어 백업/복구, 장애 알림, 동시 참여·부하 검증.
- [ ] 안전한 백엔드 CI 배포·이전 이미지 보관·롤백 절차.
- [ ] 별도 VM·네트워크 격리, 이후 필요에 따른 Gateway·서비스 분리.
- [ ] Cloudflare R2 이관·리사이즈/압축·미사용 파일 정리. R2는 선택한 방향이며 현재 구현은 아니다.
- [ ] 지도·Apple/Google 로그인·관리자 권한·앱 채팅.

## 연결 문서

[08-work-status](08-work-status.md) · [09-backend-architecture](09-backend-architecture.md) · [10-gmail-setup](10-gmail-setup.md) · [11-development-deployment](11-development-deployment.md) · [12-production-deployment](12-production-deployment.md) · [06-decisions](06-decisions.md)

2026-10-02 확장: [13-host-auth-monitoring](13-host-auth-monitoring.md)에서 JWT·이미지 한계·Gateway·Grafana/Prometheus·지연 조사 결과를 확인한다.
