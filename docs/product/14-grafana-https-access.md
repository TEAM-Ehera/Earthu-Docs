---
title: Grafana 운영 HTTPS 접속
tags: [얼쑤, 운영, 모니터링]
status: 운영 적용 완료 · HTTPS 로그인 검증
updated: 2026-10-02
---

# Grafana 운영 HTTPS 접속

## 현재 상태

Grafana는 DB VM의 Docker 서비스이며 로컬 컴퓨터에서 실행되는 서비스가 아니다. 서버 재부팅 시 restart: unless-stopped로 자동 실행한다. HTTPS 주소로 접속하므로 사용자 컴퓨터의 SSH 터널은 필요 없다.

2026-10-02 관리자 SSH 접근 규칙을 [접속 IP 비공개]/32로 갱신하고 API 사설 IP [접속 IP 비공개]/32에서 DB의 TCP 3001로 연결하도록 OCI 규칙을 추가했다. Grafana는 접속 작업 전에 이미 14시간 동안 실행 중이었으며 이번에 HTTPS 경로를 추가했다.

## 접속 방식

- 운영 URL: Grafana 로그인 (주소는 운영 담당자가 별도 전달).
- 대시보드: 얼쑤 서버 모니터링 (주소는 운영 담당자가 별도 전달). 로그인이 필요하다.
- API VM의 기존 Caddy가 HTTPS를 처리하고 DB VM의 [접속 IP 비공개]:3001로 전달한다.
- Grafana 계정 로그인. 기존 관리자 아이디 [개인 계정 발급 요청]과 기존 비밀번호를 사용한다. 비밀번호는 Git 제외 eolssu-api/.env.monitoring의 GRAFANA_ADMIN_PASSWORD에 보관한다.
- 익명 조회와 회원가입은 비활성화하고 HTTPS 전용 로그인 쿠키를 설정한다.
- DB VM에는 공인 IP를 추가하지 않는다. 3001은 API VM의 내부 IP [접속 IP 비공개]/32에서만 접근을 허용한다. Prometheus 9090과 PostgreSQL 5432의 기존 접근 범위는 바꾸지 않는다.
- 팀원은 관리자 비밀번호를 공유하기보다 개인 Grafana 계정을 발급받고 조회 목적이면 Viewer 권한을 사용한다. 개인 계정 생성은 아직 진행하지 않았다.

## 적용 절차 기록

1. Oracle 로그인 후 기존 관리자 SSH IP 규칙을 현재 IP /32로 갱신한다. 접근 범위를 전체 인터넷으로 확대하지 않는다.
2. 기존 Grafana 서비스와 데이터 볼륨, 로그인 설정을 확인한다.
3. DB 보안 규칙과 호스트 방화벽에서 [접속 IP 비공개] → TCP 3001만 허용한다.
4. DB의 기존 .env.monitoring에 deploy/grafana.env.example 설정을 합친다. 기존 비밀번호는 변경하지 않는다.
5. 수정한 compose.monitoring.yaml로 Grafana를 재생성한다. 데이터 볼륨은 유지한다.
6. Caddyfile.grafana 내용을 실제 공유 Caddy 설정에 추가하고 설정 검증 후 reload한다. Caddy validate 성공 후 reload했고 TLS 인증서가 정상 발급되었다.
7. 외부 HTTPS 로그인 화면 200, 미로그인 대시보드 API 401, 기존 관리자 계정 로그인 200, 인증 후 대시보드 200 및 10개 패널, Secure 세션 쿠키를 확인했다. Prometheus api-prod/api-dev/node-api/node-db 네 수집 대상이 모두 UP이다.

DB 호스트의 DOCKER-USER 규칙은 conntrack의 ORIGINAL 방향과 원래 목적지 [접속 IP 비공개]:3001을 기준으로 API 사설 IP만 허용한다. 응답 트래픽을 차단하지 않으며 netfilter-persistent save로 저장했다. Grafana 데이터 볼륨 eolssu-monitor_grafana_data와 기존 비밀번호를 유지했다. 배포 전 Caddy·Compose·환경 파일을 서버에 백업했다.

기존 scripts/open-monitoring.sh는 이전 localhost 바인딩용이다. 현재 접속에는 사용하지 않는다. HTTPS root_url과 Secure 쿠키가 설정되어 있으므로 기본 접속 경로는 위 운영 URL이다.

문제가 생기면 Caddy의 Grafana 사이트 블록을 제거하고 Grafana 바인딩을 [접속 IP 비공개], cookie_secure를 false, root_url을 기존 localhost 주소로 되돌린다. 데이터 볼륨은 삭제하지 않는다.

관련: [13-host-auth-monitoring](13-host-auth-monitoring.md)

참고: [Grafana 프록시 구성](https://grafana.com/tutorials/run-grafana-behind-a-proxy/) · [Grafana 보안 설정](https://grafana.com/docs/grafana/latest/setup-grafana/configure-security/configure-security-hardening/).
