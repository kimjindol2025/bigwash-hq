# bigwash-hq 구현 상태

**1차 잠금.** 기록: [`LOCK-V1.md`](LOCK-V1.md). 2차 포트 밴드: 본사 `30000`–`39999`, 현장 `40000`–`49999`. `10000` 미만은 쓰지 않는다.

정본: [`HQ-BUILDER-SPEC.md`](HQ-BUILDER-SPEC.md)  
저장소: https://github.com/kimjindol2025/bigwash-hq · `main`

## 진입

- URL: `/hq/login.html`
- `npm start` = AFJ HQ only (`src/hq-server.fl`)
- 레거시 고객입구(`/register.html`, `/login.html` 등) = **404**

## 잠긴 UI 슬라이스

| 화면 | 상태 |
|------|------|
| 전화 데스크 | 검색(번호 부분일치·상호) → 카드 → 장비 → 출장/상담. 최근출장은 **요약 미리보기** |
| 고객 카드 | 필수+권고 필드, 장비, 구매확정, 무상힌트 |
| 티켓 서랍 | 고객/요청 · 배정(N+용병) · 장바구니=견적 · 일지/사진 썸네일 |
| 스케줄 | 직원/용병 선선택 후 부여 |
| 사내몰 | 상품 마스터 (`fulfill_type`) — 장바구니는 티켓 서랍 |
| 정산 | 탭 `미수` \| `출장수금` \| `경비` \| `운영비`. 급여는 직원 카드 |
| 직원 | 카드에 **급여** 블록(기본+수당−공제=총액). 용병은 급여 없음 |
| 보고 | 일/주/월 표 + **엑셀 내보내기**(CSV). 수기 보고 없음 |

## 돈 모듈 1차 (손테스트 기준)

1. 티켓 정산 `미수` → 정산>미수에 같은 한글 뱃지  
2. 미수 → 카드완납 변경 시 미수 목록에서 빠지거나 출장수금에 완납  
3. 경비 입력 → 승인 → 대시보드 경비대기 감소  
4. 운영비 이번달 임대 → 월 보고 `출장+운영+경비`에 포함  
5. 직원 급여 저장 → 월 보고 `급여총액`  
6. 용병 목록에 월급 칸 없음  
7. 보고 일/주/월 전환 + CSV 다운로드  
8. 상담·일반 역할은 급여 저장 버튼 숨김(또는 API 403)

API: `GET /hq/settlements?tab=unpaid|collected`, `GET/POST /hq/expenses`(+decide), `GET/POST /hq/opex`, `GET/POST /hq/payroll`(경리·관리자), `GET /hq/reports?period=`, `POST /hq/tickets/:id/finance`

## 성능

- 대시보드: DB 왕복 축소 + **10초 서버 캐시** + 브라우저 즉시 표시 (`expense_pending` 실집계)
- 티켓: `/hq/tickets/:id/bundle` 1회 로딩
- 참조데이터(직원·권역·상품) 60초 클라이언트 캐시

## HQ 1차 패치

완료. 부분수금은 모달(받은금액·수단), 스케줄 부여는 날짜 옆 시간 입력(방문시각 prompt 없음). 용병 이름은 `hq_ticket_assignees` 기준으로 선택 인원 일정에 표시. 급여 블록·상품 원가는 경리·관리자(`admin`/`finance`/`accountant`)만. 직원 앱은 별 레포.

현장 화면은 이 레포에 없다. 수신만: `GET /hq/tickets?mine=1`(동행 포함), `POST /hq/tickets/:id/log`, `POST /hq/me/day-close`(`clock_out`|`return_hq`), `POST /hq/me/password`. 기사 역할은 자기 배정 티켓만 수정.

## 테스트

```bash
npm test             # hq19 + hq20 + hq-money
npm run test:hq19    # 1–10
npm run test:hq20    # 11–20
npm run test:money   # 돈 모듈 손테스트 1–8
```

## 아직 얇은 점

- 브라우저 클릭 스위트 없음 (돈 모듈은 API 스위트)
- 명세 PNG는 세로 템플릿 + 동일 content (고품질 텍스트 래스터 합성은 후속)
