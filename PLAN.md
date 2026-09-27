# bigwash-as — 구현자 작업 지시 인덱스

**구현자:** Grok (이 에이전트)  
**총괄 구현:** 지시서가 오면 착수한다.  
**지금 단계:** 문서 정리만. **코드·화면·서버 구현 착수 전.**

---

## 문서 지도 (정본)

| 우선 | 문서 | 내용 |
|------|------|------|
| 1 | [`docs/HQ-BUILDER-SPEC.md`](docs/HQ-BUILDER-SPEC.md) | **본사 빌더 지시서 정본** |
| 2 | [`docs/IMPLEMENTATION-STATUS.md`](docs/IMPLEMENTATION-STATUS.md) | 구현·수락테스트 보고 |
| 3 | [`docs/HQ-CRM-AS-REVIEW.md`](docs/HQ-CRM-AS-REVIEW.md) | 이전 검수 고정값 |
| 4 | [`docs/OPEN-DECISIONS.md`](docs/OPEN-DECISIONS.md) | 5문항 잠금 |
| 5 | [`docs/ACCEPTANCE-TESTS.md`](docs/ACCEPTANCE-TESTS.md) | 이전 DoD (참고) |

구버전 로드맵(`PHASE2_ROADMAP.md` 등)은 참고용. **제품 정본은 위 docs/**.

---

## 착수 게이트

1. [x] `OPEN-DECISIONS.md` 5문항 — 검수 권고로 잠금 (2026-09-27)
2. [x] 오너 「1차 착수」 지시
3. [x] **1차 DoD** — `npm run test:hq` PASS 10/10 (상세: `docs/IMPLEMENTATION-STATUS.md`)

### 1차 진입점
- URL: http://127.0.0.1:30000/hq/login.html
- 계정: `admin` / `admin123` (시드: `tech_a`/`tech123`, `tech_b` 휴직)
- 서버: `src/hq-server.fl` (`npm start`)
- 스키마: `db/hq-schema.v1.json` (`bash scripts/provision-hq.sh`)

---

## 역할

| 역할 | 담당 |
|------|------|
| 기획·검수 피드백 | 사용자 / 검수 문서 |
| 총괄 구현 | **Grok Builder (나)** |
| 기존 `src/*.fl` 프로토타입 | 실험 골격. 착수 시 폐기·이식은 지시서에 따름 |

---

## 스택 (잠금 방향)

FreeLang AFJ + AFL-DB. Express로 업무 본체 재작성 금지.  
세부 UI(HTML vs Front)는 착수 시 확정.
