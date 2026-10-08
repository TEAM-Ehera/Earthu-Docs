---
title: "얼쑤 팀 Gmail 인증 메일 설정"
aliases: ["얼쑤 Gmail SMTP"]
service: "얼쑤"
team: "에헤라디야"
type: "operations"
version: "1.1"
status: "로컬 Gmail 연결·API 적용 완료 · 학교 메일 수신 확인 전"
created: "2026-10-01"
updated: "2026-10-01"
tags: ["얼쑤", "개발/메일", "운영/설정"]
---

# 팀 Gmail 인증 메일 설정

[문서 홈](README.md) · [작업 현황](08-work-status.md) · [백엔드 구조](09-backend-architecture.md)

## 목적과 흐름

팀 Google 계정은 **발신 계정**이다. 가입자는 `.ac.kr`·`.edu` 학교 이메일로 인증 코드를 받는다. 가입자가 Gmail 계정으로 가입하도록 바꾸는 설정이 아니며, Google 간편 로그인과도 별개다.

`회원 가입 → API 코드 생성 → 팀 Gmail SMTP 발송 → 학교 메일에서 코드 확인 → 웹에 입력 → 학교 인증 → 프로필 작성`

6자리 코드, 10분 유효, 입력 시도 5회, 재발송 간격 60초는 기존 정책을 유지한다. 한국어/영어 HTML·일반 텍스트 메일 템플릿은 `src/main/resources/mail/school-verification.html`에 있다.

## 로컬 설정

API 저장소의 `.env`에 입력한다. 파일은 Git 제외, 권한 600이다. 아래는 예시이며 실제 비밀번호를 문서에 저장하지 않는다.

```dotenv
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=팀의_Google_이메일
SMTP_PASSWORD=16자리_Google_앱_비밀번호
SMTP_AUTH=true
SMTP_STARTTLS=true
MAIL_FROM=
```

`MAIL_FROM`을 비우면 적용 도구가 발신 계정으로 채운다. 앱 비밀번호 표시용 공백은 제거한다. 일반 Google 로그인 비밀번호를 입력하지 않는다. Google 앱 비밀번호는 2단계 인증이 필요하며 조직 계정 정책 등에 따라 사용 불가할 수 있다. [Google 앱 비밀번호](https://support.google.com/accounts/answer/185833)

SMTP는 Gmail 호스트의 587 포트·인증·STARTTLS를 사용한다. TLS 사용 시 암호화를 요구하고 서버 인증서를 확인한다. 로컬 Mailpit 설정은 TLS 비활성 구성을 유지한다. [Google SMTP 안내](https://support.google.com/mail/answer/7104828)

## 확인과 적용

API 저장소에서 실행한다.

```sh
python3 scripts/gmail_smtp.py
python3 scripts/gmail_smtp.py --apply
```

- 첫 명령: 형식 확인, Gmail TLS 연결·계정 인증. 메일은 발송하지 않는다.
- 두 번째: 확인 성공 후 앱 비밀번호 공백·발신 주소 정규화, API만 재빌드·재시작. 기존 DB·이미지 volume은 유지한다.
- 실패: 비밀값을 출력하지 않고 설정/인증/연결 오류로 안내한다. 실패한 계정 설정으로 API를 재시작하지 않는다.
- Docker가 실행되어 있어야 한다. `.env.example`은 새 개발자를 위해 Mailpit 기본값을 유지한다.

## 실제 기능 확인

1. API health가 정상인지 확인한다.
2. 웹 `/auth`에서 실제 학교 이메일로 가입한다. 가입 성공은 Gmail SMTP가 요청을 수락했다는 뜻이며 최종 수신함 도착 보장은 아니다.
3. 학교 메일 수신함과 스팸함에서 얼쑤 HTML 메일을 확인한다.
4. 받은 코드를 웹에 입력하고 프로필 작성 화면으로 이동하는지 확인한다.
5. 잘못된 코드, 만료 코드, 재발송 제한, 기존 회원 로그인을 확인한다.

네트워크·SMTP 인증만 통과한 상태를 ‘실제 학교 메일 수신 완료’로 기록하지 않는다. 현재 Oracle 개발·운영 API의 권한 600 환경 파일에 발신 설정을 적용했다. 실제 인증은 [운영 웹](https://earthuu.vercel.app/auth)에서 사용자가 진행한다. 개발 웹은 별도 DB를 사용하므로 개발에서 만든 계정으로 운영에 로그인할 수 없다.

## 오류 구분

| 현상 | 확인할 내용 |
|---|---|
| 설정 도구가 비밀번호 형식 오류 | 앱 비밀번호 16자리, 다른 항목에 붙여 넣지 않았는지, 저장 여부 |
| Gmail 인증 실패 | 계정 이메일, 앱 비밀번호, 2단계 인증, Workspace 정책, 비밀번호 변경으로 앱 비밀번호 회수 여부 |
| 연결 실패 | 인터넷·방화벽·587 포트·TLS·Google 서비스 상태 |
| API 가입 503 | SMTP 전달 실패. 비밀값을 가린 상태로 서버 진단 필요 |
| 전송 성공인데 메일 없음 | 학교 스팸함·메일 보안/격리 정책·반송 메일 |
| 기존 미인증 회원 중복 | 새 가입 대신 인증 코드 재발송 |

## 현재 검증 상태

설정 도구의 입력 검증, 기존 `.env` 항목 보존, 파일 권한 600, TLS→로그인 호출, 확인 단계에서 메일을 보내지 않는 동작을 대체 SMTP로 확인했다. 2026-10-01 팀 계정의 Gmail STARTTLS 연결·SMTP 인증에 성공했고, API Docker 컨테이너에 설정을 적용해 재빌드·재시작했다. Oracle API 서버에서도 Gmail STARTTLS·SMTP 계정 인증을 확인했고 운영 환경에 같은 발신 설정을 적용했다. 실제 메일 발송·학교 수신함 도착·코드 인증은 확인하지 않았다. 운영 가입/로그인 경로는 빈 입력 400으로 연결을 확인했으며 메일을 보내지 않았다. [12-production-deployment](12-production-deployment.md)를 따른다.
