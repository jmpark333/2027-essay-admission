# JOB.md — OpenCode/Claude Code 자동화 워크플로우

> GitHub 이슈 코멘트 `/oc` 또는 `/cc` → AI 분석 → 파일 수정 → PR 생성 → 수동 승인 → 배포

---

## 📌 현재 상황

| 항목 | 값 |
|------|-----|
| 레포지토리 | `jmpark333/2027-essay-admission` |
| 워크플로우 파일 | `.github/workflows/opencode.yml` |
| AI 모델 | `big-pickle` (OpenCode Zen, 무료) |
| API 엔드포인트 | `https://opencode.ai/zen/v1/chat/completions` |
| API 키 | `secrets.ZEN_API_KEY` |
| 상태 | ✅ **정상 동작 확인** (테마 변경 PR 2건 병합 완료) |

---

## ✅ 동작 방식

1. **이슈/PR에 `/oc` 또는 `/cc` 코멘트 작성**
2. **AI 분석**: 파일 목록 + `index.html` 전체 내용 주입 → JSON 편집 계획 생성
3. **파일 편집**: `plan.json` 기반 search/replace 적용
4. **브랜치 생성 + 커밋 + 푸시**
5. **PR 자동 생성** (+ 이슈에 PR 링크 코멘트)
6. **사용자가 PR 승인/병합** → main 반영 → Vercel 자동 배포

> ⚠️ main 반영(merge)은 **항상 사용자가 직접 승인**. AI가 브랜치/PR 생성까지만 자동 수행.

---

## 🔧 워크플로우 구조

- **트리거**: `issue_comment` 생성 시 `/oc`, `/opencode`, `/cc` 명령어 감지
- **Job 구성**: `oc` + `cc` 두 개 (동일 로직, 명령어만 다름)
- **Step 순서**:
  1. `actions/checkout@v4` — 레포 체크아웃
  2. `actions/github-script@v7` — 👀 eyes 리액션
  3. `actions/github-script@v7` — Zen API 호출 (3회 재시도 + 응답 검증)
  4. `bash` + `node` — AI 응답(base64) → `plan.json` → 파일 편집
  5. `bash` — 브랜치 생성, 커밋, 푸시
  6. `actions/github-script@v7` — PR 생성 + 코멘트 알림

### 시스템 프롬프트 핵심
- 레포 설명: 2027학년도 논술전형 달력
- 데이터 구조: `events.deadlines[]`, `events.exams[]`, `events.results[]`
- 파일 목록 + **index.html 전체 내용 주입** (28KB, 잘라내기 없음)
- 응답 형식: JSON `{explanation, branch, edits[{file, old, new}]}`
- 대학명 규칙: 짧은 형태 + 따옴표 (`'한양대'` NOT `'한양대학교'`)
- RULES: "전체 파일 제공, 편집 거부 금지", "old는 프롬프트의 정확한 텍스트만 사용"

---

## 📚 API 설정

```javascript
{
  model: "big-pickle",
  max_tokens: 16384,
  temperature: 0.3
  // OpenCode Zen (https://opencode.ai/zen/v1/chat/completions)
  // OpenAI 호환, Authorization: Bearer <ZEN_API_KEY>
}
```

---

## 🛠️ 수정 이력 (문제 해결 과정)

### 1. 모델/API 전환: Nous Research → OpenCode Zen
- `meituan/longcat-2.0:free`: `reasoning_effort: "high"` 시 토큰을 reasoning에 소모, `content: null` → JSON 파싱 실패
- `stepfun/step-3.7-flash:free`: reasoning이 **mandatory** → `missing tags` 400 에러
- `poolside/laguna-s-2.1:free`: 524 타임아웃 / 429 용량 초과 지속
- **`big-pickle` (OpenCode Zen)**: ✅ 정상 동작 — 200 응답, `finish_reason: "stop"`

### 2. 안정성 개선
- **3회 재시도 루프**: 524/429/JSON 파싱 실패 시 5초·10초·15초 간격 자동 재시도
- **base64 전달**: AI 응답 JSON을 base64 인코딩해 스텝 간 전달 → 홑따옴표/백틱/`$` 특수문자 문제 원천 차단 (`'밝은: command not found'` 해결)
- **plan.json 파일 기반**: 스텝 간 데이터 공유 안정화
- **Node 20 deprecation 경고 해결**: `ACTIONS_ALLOW_USE_UNSECURE_NODE_VERSION: true`
- **reasoning_content fallback**: content가 비어 있으면 reasoning에서 JSON 추출

### 3. 프롬프트 개선
- **index.html 전체 주입**: 8000자 잘라내기 → 전체 28KB (AI가 "truncated"라며 편집 거부하던 문제 해결)
- **CSS 생략 제거**: `<style>` 블록까지 포함해야 테마/스타일 편집 가능
- **RULES 강화**: "편집 거부 금지", "old는 정확한 텍스트만"

### 4. 권한 설정
- **PR 생성 권한**: GitHub 리포지토리 설정에서 `can_approve_pull_request_reviews: true`로 변경 (Actions가 PR 생성 못 하던 문제)

---

## 📋 현재 제약 사항

- **편집 대상**: `index.html` 단일 파일 (파일 목록/내용은 주입되지만 `edits[]`가 기존 파일 치환만 지원)
- **새 파일 생성 불가**: `create` 타입 미지원
- **PR 승인**: 수동 (자동 merge 아님)

---

## 🔗 관련 링크

- Actions 로그: https://github.com/jmpark333/2027-essay-admission/actions
- 워크플로우 파일: `.github/workflows/opencode.yml`
- 대상 파일: `index.html`

---

*최종 수정: 2026-09-01 (ZEN API 전환 + /oc 정상 동작 확인)*
