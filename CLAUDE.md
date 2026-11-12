# SPORTS LIVE! — Claude 작업 안내

이 저장소는 한국어 스포츠 대시보드 웹 앱(PWA) **SPORTS LIVE!** 입니다.
소유자는 **집 컴퓨터(메인)와 다른 컴퓨터 두 대**에서 Claude와 작업합니다. **GitHub `main` 브랜치가 기준본**입니다.

- 공개 링크: https://gustjrwjs.github.io/Sports-Dashboard/static/
- 저장소: https://github.com/gustjrwjs/Sports-Dashboard (GitHub Pages: main / root)
- 소유자와는 **한국어**로, 쉬운 말로 대화합니다.

## 📋 다음 할 일 (소유자가 요청함 · 묻지 말고 순서대로 진행, 끝나면 이 목록에서 지우기)

1. **과거 시즌 보기**
   - 리그 이름 옆에 시즌 선택 메뉴(예: `2026-27 ▼`). 리그별로 ESPN이 실제 데이터를 주는 시즌만 표시(standings `?season=YYYY`, scoreboard `?dates=YYYYMM` 등으로 확인).
   - 고른 시즌의 최종 순위표(구간 색 포함), 경기 결과(주/라운드별)와 경기 상세(라인업·득점·기록), 토너먼트 대진표, 팀 분석(그 시즌 성적·주목할 선수).
   - 부상·뉴스·LIVE는 현재 시즌에서만. 오래된 시즌은 세부 정보가 없을 수 있으니 빈 상태 안내. 현재 시즌 기능은 그대로 유지.
2. (선택) MLS 플레이오프 대진표(`BR_KIND`에 추가) — 리그 6개 추가 때 보류함.

각 작업 후: 로컬 테스트(PC·모바일 375px) → GitHub 업로드 → 공개 링크 확인 → 한국어로 결과 보고 + 링크.

## 작업 규칙 (소유자가 정한 것)

1. **작업 시작 전에 GitHub의 최신 파일로 로컬을 맞춥니다.** 다른 컴퓨터에서 고친 내용이 있을 수 있습니다.
   - Git이 없으면 PowerShell로 받습니다. 예:
     `Invoke-WebRequest https://raw.githubusercontent.com/gustjrwjs/Sports-Dashboard/main/static/index.html -OutFile static/index.html`
     (README.md, LICENSE, app.py, supabase_setup.sql, CLAUDE.md, static/manifest.webmanifest, static/sw.js, static/icons/*.png 도 같은 방식)
   - 로컬 파일이 GitHub보다 새로운 경우(아직 안 올린 수정)엔 덮어쓰기 전에 소유자에게 확인합니다.
2. **수정하면 묻지 말고 GitHub에도 바로 올립니다.** 그 뒤 공개 링크에서 반영됐는지 확인합니다(배포에 30~60초).
3. **업데이트가 끝나면 항상 마지막에 공개 링크를 줍니다.**
4. **저작권 표시 유지**: All rights reserved (© 2026 gustjrwjs). MIT/오픈소스로 되돌리지 않습니다.

## 업로드 방법 (Git 미설치 컴퓨터)

소유자의 Chrome(GitHub 로그인됨) + Claude in Chrome 확장으로 올립니다.
- 루트 파일: `https://github.com/gustjrwjs/Sports-Dashboard/upload/main` → "Choose your files" 입력에 file_upload → **Commit directly to the main branch** → 요약 입력 → Commit changes
- `static/` 파일: `.../upload/main/static`, 아이콘: `.../upload/main/static/icons` (폴더별로 따로 올려야 함)
- Git이 설치된 컴퓨터라면 `git pull` → 수정 → `git commit` → `git push` 로 해도 됩니다.

## 구조

- `static/index.html` — 화면 전체(HTML/CSS/JS 한 파일). 리그 설정은 스크립트의 `LEAGUES`, `SPORT_GROUPS`.
- `static/manifest.webmanifest`, `static/sw.js`, `static/icons/` — 휴대폰 앱 설치(PWA). 캐시 이름(`shell-vN`)은 아이콘·셸 파일이 바뀔 때만 올림.
- `app.py` — 로컬 테스트 서버(표준 라이브러리). `python app.py --no-browser` (PORT 환경변수, 기본 8765). `/espn/...` 를 ESPN API로 중계.
- `supabase_setup.sql` — 커뮤니티 게시판 DB 설정. Supabase 프로젝트 URL·publishable 키는 `index.html`의 `const SB`.
  - service_role 키나 운영자 비밀번호는 절대 요구·저장하지 않습니다. DB 변경은 소유자가 Supabase SQL Editor에서 실행.

## 데이터

- ESPN 공개 API(`site.api.espn.com/apis/...`, 키 없음, CORS 허용). 순위 `apis/v2/sports/{sport}/{slug}/standings`, 일정 `scoreboard?dates=YYYYMMDD|YYYYMM`(기간 범위는 400), 팀 일정, 경기 상세 `summary?event=`.
- 선수 한국어 이름·사진: 위키데이터 SPARQL. 배당: ESPN pickcenter(DraftKings 경기 전 기준).
- KBO는 무료 공개 데이터가 없어 보류(봇 차단 우회 스크래핑 금지).

## 테스트

- 로컬 서버 띄우고 브라우저로 PC 폭과 모바일(375px) 폭 모두 확인. 가로 넘침 없게.
- 다크 모드 색은 `:root` 변수 사용.
