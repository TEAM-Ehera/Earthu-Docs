---
title: Oracle 개발 환경 배포
tags: [얼쑤, 개발, 배포]
status: 개발 API 배포 완료
updated: 2026-10-01
---

# Oracle 개발 환경 배포

## 현재 구성

A1 추가 VM 생성은 오사카 AD-1 용량 부족으로 실패했다. 사용자 합의에 따라 기존 무료 Micro VM 두 대를 개발 환경으로 사용한다. VM 이름에는 prod가 남아 있지만 현재 실행 환경은 **dev**이며 이후 운영 API를 별도 Docker 프로젝트와 DB로 추가했다. 최신 운영 상태는 [12-production-deployment](12-production-deployment.md)를 따른다.

| 역할 | VM 이름 | 접속 | 실행 환경 |
| --- | --- | --- | --- |
| API·Caddy | eolssu-prod-api | 공인 [접속 IP 비공개] / 내부 [접속 IP 비공개] | Docker 프로젝트 eolssu-dev |
| PostgreSQL | eolssu-prod-db | 내부 [접속 IP 비공개] / 공인 IP 없음 | Docker 프로젝트 eolssu-dev-db |

- 개발 API: 운영 담당자에게 전달받은 HTTPS 주소
- 개발 웹: https://eolssu-web-git-develop-thesoftbellys-projects.vercel.app
- API: Java 21 / Spring Boot 4.1.1 / dev 프로필.
- 배포 이미지: develop `f505ced9067efdf5160ba982855a1b28a20a3d63`의 GitHub Actions 빌드 결과.
- DB: PostgreSQL 17, 개발 DB `eolssu_dev`. 로컬 데이터를 복사하지 않았다.
- 두 VM: Docker Engine·Compose, RAM 1GB, swap 2GB. swap은 RAM 증설을 대체하지 않는다.
- API·DB의 환경 파일은 각각 `/home/ubuntu/eolssu-dev/.env.dev`, 권한 600. DB 서버에는 SMTP 비밀값을 복사하지 않았다.
- 개발 DB·미디어·Caddy 인증서 데이터는 Docker 볼륨에 보존한다. `down -v`로 삭제하지 않는다.

## 접근과 연결

OCI 보안 목록에서 SSH는 현재 관리자 IP와 API 내부 IP에서만 허용한다. HTTP/HTTPS 80·443은 공개하고, PostgreSQL 5432는 API 내부 IP `[접속 IP 비공개]`에서만 허용한다. API 8080과 DB는 인터넷에 직접 공개하지 않는다. 관리자 접속 IP가 바뀌면 SSH 허용 규칙을 갱신해야 한다.

DB 서버의 설치는 API를 경유한 SSH 접속과 localhost SOCKS 터널로 진행했다. 설치 후 임시 터널을 종료했다. 이후 패키지 업데이트와 컨테이너 이미지 전달도 이 접속 경로를 사용해야 한다.

Vercel `API_ORIGIN`은 **Preview의 develop 브랜치에만** 개발 API 주소로 지정했다. `NEXT_PUBLIC_API_URL=same-origin` 설정으로 웹의 `/v1/*` 요청을 API에 전달한다. Production/main 설정은 변경하지 않았다. Preview에는 기존 Vercel 로그인 보호가 적용된다.

임시 sslip.io 호스트는 공인 IP를 DNS 주소로 해석한다. 공인 IP 변경 시 API_HOST·Vercel 환경 변수·인증서 연결을 함께 갱신해야 한다.

## 확인 결과

- HTTPS 인증서와 `/actuator/health`: UP.
- Flyway V1/V2: 모두 적용 성공, JPA 스키마 검증 통과.
- `/v1/events`: 200. 개발 DB는 빈 상태로 시작한다.
- 미로그인 `/v1/me`: 401.
- Vercel develop 재배포: Ready (`9J18iumatgQmLmLGV89ai7pKrpkV`).
- 개발 웹 새로고침으로 발생한 `/v1/events` 200·`/v1/me` 401을 Oracle Caddy에서 확인했다. Vercel 웹 → 같은 출처 프록시 → Oracle API 통신이 실제로 연결된다. 웹 콘솔 오류도 없었다.
- 통신 확인 중 요청 헤더·쿼리를 제외한 임시 접근 로그를 사용했으며 확인 후 원래 Caddy 설정으로 복구했다.
- 시연용 `/v1/local/reports`: 404.
- 일반 Gmail 주소의 학교 인증 검사: 400.
- 서버에서 Gmail STARTTLS·SMTP 계정 인증 성공. 실제 테스트 메일은 보내지 않았다.
- 한 번 측정한 컨테이너 메모리: API 약 216MiB, Caddy 약 19MiB, DB 약 38MiB. 이 값은 동시 사용자의 운영 부하 검증 결과가 아니다.

## 남은 작업

- 실제 학교 메일 수신 → 가입·코드 인증 → 프로필 → 모임 생성·참여 검증.
- 원격 DB·미디어 백업과 복구 검증, 장애 알림, 운영 부하 확인.
- 자동 백엔드 배포 접속 경로 구성. 현재 GitHub Actions는 이미지 빌드까지 통과했고 SSH 배포는 비활성화 상태다. 관리자 IP 제한과 GitHub 호스팅 runner의 동적 IP가 맞지 않으므로 별도 runner 또는 안전한 접속 경로가 필요하다.
- A1 확보 후 운영 환경 구성. 개발·운영의 Docker 프로젝트·DB 계정·DB·볼륨·환경 설정을 분리한다. 같은 VM을 공유하면 서버 장애와 자원 부족은 공유한다.

관련 문서: [08-work-status](08-work-status.md), [09-backend-architecture](09-backend-architecture.md), [10-gmail-setup](10-gmail-setup.md).
