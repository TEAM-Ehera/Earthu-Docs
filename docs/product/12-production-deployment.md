---
title: 운영 서버 배포 및 API 연결
tags: [얼쑤, 운영, 배포]
status: 배포 완료
updated: 2026-10-01
---

# 운영 서버 배포 및 API 연결

## 404 원인과 수정

운영 Vercel 환경에는 API_ORIGIN이 없었다. develop Preview에만 값이 있어 운영 웹의 /v1 요청에 rewrite가 생성되지 않았다. Production API_ORIGIN을 아래 운영 API로 설정하고 웹 main을 develop의 검증된 코드로 갱신하여 재배포했다.

- 운영 웹: https://eolssu-web.vercel.app
- 운영 API: 운영 담당자에게 전달받은 HTTPS 주소
- Vercel 배포: HAm392tAahWHmswq9ifh4FvpEfeC / Production Ready.
- 웹 코드: 2160c4a. API 실행 이미지: f505ced의 기존 검증된 AMD64 이미지, Spring prod 프로필.

## 구성과 분리

현재 무료 Micro API VM을 개발·운영이 공유한다. 운영 Docker 프로젝트는 eolssu-prod, 컨테이너는 eolssu-prod-api-1, 환경 파일은 /home/ubuntu/eolssu-prod/.env.prod(600)다. 운영 compose는 compose.prod-shared.yaml이다. 개발 프로젝트는 유지한다.

DB VM의 기존 PostgreSQL 인스턴스 안에 운영 DB eolssu_prod와 별도 로그인 계정 eolssu_prod를 생성했다. 개발 DB eolssu_dev를 복사하지 않았다. 운영 미디어는 eolssu-prod_media_data 볼륨에 별도로 저장한다. 운영 환경 파일과 DB 비밀번호는 Git에서 제외한다.

Caddy는 기존 컨테이너를 공유한다. deploy/Caddyfile.shared를 API VM의 /home/ubuntu/eolssu-dev/deploy/Caddyfile에 설치했다. 개발 호스트는 api:8080, 운영 호스트는 prod-api:8080으로 연결하며 운영 API는 기존 eolssu-dev_default 네트워크의 prod-api 별칭을 사용한다. **개발 재배포 시 단일 호스트 Caddyfile로 덮어쓰면 운영 연결이 끊기므로 Caddyfile.shared를 유지해야 한다.**

기존 공인 IP·80/443·SSH·DB 접근 규칙을 그대로 사용한다. 운영 때문에 외부 포트를 추가하지 않았다. 개발·운영은 VM·프록시·Docker 네트워크·PostgreSQL 프로세스를 공유하므로 자원 부족과 서버 장애가 양쪽에 영향을 준다. 추후 A1 또는 별도 서버 확보 후 분리한다.

## 검증

운영 웹 주소를 통해 직접 요청하여 다음 응답을 확인했다.

| 요청 | 결과 |
| --- | --- |
| GET /v1/events?sort=recent | 200, 빈 목록 |
| GET /v1/auth/school-email, POSTECH 도메인 | 200, 포항공과대학교 자동 인식 |
| GET /v1/me, 미로그인 | 401 |
| POST /v1/auth/login, 빈 입력 | 400 |
| POST /v1/auth/register, 빈 입력 | 400 |

API HTTPS 인증서 발급 완료, health UP, 운영 DB Flyway V1/V2 적용 성공. 빈 입력 검증으로 경로 연결만 확인했으며 실제 계정 생성·인증 메일 발송은 하지 않았다. 학교 인증은 사용자가 진행한다. 운영 DB는 비어 있어 모임 0개가 정상이다.

## 남은 작업

- 실제 학교 메일 수신·코드 입력·프로필 생성·로그인·모임 생성·참여 검증.
- DB·미디어 백업 및 복구 검증, 서버 장애 알림.
- 안전한 CI 배포 접속 구성. 현재 백엔드 배포는 수동이며 GitHub runner SSH 자동 배포는 비활성화되어 있다.
- 별도 서버 확보 및 개발·운영 장애/자원 격리.

관련: [11-development-deployment](11-development-deployment.md), [08-work-status](08-work-status.md), [10-gmail-setup](10-gmail-setup.md).
