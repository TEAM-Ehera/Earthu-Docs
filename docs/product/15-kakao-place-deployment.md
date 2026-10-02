# 카카오 장소 검색·Redis 배포 기록 (2026-10-02)

모임 작성·수정 화면에서 장소를 검색하고 선택하면 주소·좌표·시군구·상세 만남 위치를 저장한다. 선택 장소를 지도에 표시하고 상세 화면에 카카오맵 링크를 제공한다. 기존 텍스트 장소 모임은 호환된다.

## 캐시와 호출 정책

- 검색 결과·좌표의 행정구역 응답: Redis 10분, 빈 결과 30초.
- 지도 SDK·지도 타일: 카카오가 브라우저에 직접 전달하며 Redis 캐시 대상이 아니다.
- 버튼/Enter로 검색한다. 입력·지도 이동마다 서버 검색하지 않으며 장소 선택 후 지도 SDK를 로드한다.
- 로그인 사용자당 30회/분, Redis 인스턴스당 외부 호출 120회/분. 개발·운영은 별도 Redis이므로 같은 카카오 앱의 총량을 함께 관측해야 한다.
- 동일 검색은 10초 잠금으로 중복 호출을 막는다. 처리 중 429, 외부 장애 502, Redis 장애 503. 외부 실패 응답은 캐시하지 않는다.
- Redis 비공개 네트워크·비밀번호 인증, 데이터 64MB/컨테이너 96MB, noeviction, 비영속. 장애·메모리 부족은 검색에만 영향을 주며 인증·모임 조회는 유지한다.

## 설정과 배포

API: `KAKAO_REST_API_KEY`, `REDIS_HOST`, `REDIS_PORT`, `REDIS_PASSWORD`, 선택적 `PLACE_CACHE_TTL`. 공유 네트워크가 있으면 `PLACE_REDIS_HOST`에 각 환경의 고유 Redis 컨테이너 이름을 지정한다. 공통 `redis` DNS 별칭이 다른 환경을 가리키는 문제를 방지한다.
웹 빌드: `NEXT_PUBLIC_KAKAO_MAP_KEY`. REST 키는 서버에만 저장한다. 실제 키·비밀번호는 Git에 포함하지 않는다. 카카오 콘솔의 허용 웹 도메인을 실제 접속 주소와 맞춘다.

개발·운영 API에 각각 `compose.places.yaml` 오버레이를 적용했다. API 이미지 `eolssu-api:places-20261002`, Flyway V4가 장소 컬럼을 추가한다. 배포 이미지는 이번 장소 기능과 기존 개발 Swagger 작업을 함께 유지했으며, 장소 기능 PR은 Swagger 변경을 포함하지 않는다. 작은 VM에서는 사전 빌드한 JAR와 `deploy/Dockerfile.runtime`으로 이미지를 만들어 Maven 빌드 부담을 줄인다.

두 DB의 마이그레이션 전 SQL 백업과 각 환경의 기존 환경변수 백업을 보관했다. 롤백은 이전 API 이미지·환경 설정으로 복귀한다. V4 컬럼은 추가형이므로 이전 코드와 호환되며 볼륨 삭제·DB 초기화를 하지 않는다. 프론트는 Vercel의 이전 운영 배포로 복귀할 수 있다.

개발 CI는 Redis 오버레이를 전달하도록 수정했다. SSH 자동 배포 활성화는 기존 `DEV_DEPLOY_ENABLED` 설정을 따른다. 이번 서버 배포는 직접 수행했다. 웹 환경변수 변경 후에는 새 빌드가 필요하다. 웹 커밋 `1220bb1`을 Preview와 Production으로 각각 빌드했다. 개발 고정 주소는 Preview에 alias를 할당하고 운영 주소는 Production에 반영했다. PR은 아직 병합하지 않았으므로 다음 develop/main 배포 전 기능 PR을 반영해야 한다.

## 확인 결과

- 백엔드 캐시·TTL·Lua 제한·잠금·인증·입력·DB 저장 테스트 통과. 임시 실제 Redis 통합 테스트 통과.
- 웹 lint/build 및 GitHub 검증 통과.
- 실제 카카오 REST 검색·행정구역 조회 200, 로컬 웹 지도 타일 표시 확인.
- 개발·운영 API readiness UP/200, 모임 조회 200, 비로그인 장소 검색 401. 각각 Redis PONG.
- 개발 Swagger 200, 운영 Swagger 404.

실제 사용자 계정으로 원격 장소 선택·등록의 끝까지 검증 여부는 PR의 최종 배포 기록을 따른다. 부하 테스트나 카카오 쿼터 전체 소진 테스트는 수행하지 않았다.

## 리뷰

- [API PR](https://github.com/TheSoftBelly/eolssu-api/pull/1)
- [웹 PR](https://github.com/TheSoftBelly/eolssu-web/pull/1)
- 상세 API 계약·Compose 실행 명령은 API 저장소 `docs/api/kakao-places.md`.
