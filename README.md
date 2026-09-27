# bigwash-hq — 본사 운영 SaaS

**정본 지시서:** [`docs/HQ-BUILDER-SPEC.md`](docs/HQ-BUILDER-SPEC.md)

전화가 입구인 **본사 PC/모바일 웹**. 고객 앱·직원 현장 앱은 이 레포에 없습니다.

## 진입

```bash
npm run provision          # HQ 스키마 (+ ext)
bash scripts/provision-hq-ext.sh   # 확장 테이블 (있으면)
npm start                  # AFJ HQ. 기본 :30000 (30000–30099)
```

브라우저: **`/hq/login.html`**  
`HQ_PORT` 가 있으면 그 포트만 씁니다. 출력: `[bigwash-hq] :30000`

현장 앱은 다른 레포입니다. 같이 띄울 때:

```bash
bash scripts/run-pair.sh
```

초기 관리자 계정은 환경변수·시드로만 두고, 문서에 실비밀번호를 적지 않습니다.  
로컬 개발 시드가 켜져 있으면 최초 로그인 후 비밀번호를 바꾸세요. (`ADMIN_PASSWORD` env)

## 스택

- FreeLang **AFJ** (`src/hq-server.fl`, `src/hq-ext.fl`)
- **AFL-DB** (`db/hq-schema*.json`)
- UI: `public/hq/`

## 테스트

```bash
npm run test:hq19          # 본사 수락 핵심
npm run test:hq20          # §20 확장분 (추가 후)
```

`npm test`는 레거시 고객접수 스위트를 돌리지 않습니다.

## 레거시

옛 고객 AS 접수(Express/`server.js`, `v9/`, `legacy/`, 옛 public 등록·조회)는 **본사 정본이 아닙니다.**  
`npm start` 경로에 포함되지 않습니다.
