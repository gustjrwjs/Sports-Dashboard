# SPORTS LIVE! — Claude 작업 안내

이 저장소는 한국어 스포츠 대시보드 웹 앱(PWA) **SPORTS LIVE!** 입니다.
소유자는 **집 컴퓨터(메인)와 다른 컴퓨터 두 대**에서 Claude와 작업합니다. **GitHub `main` 브랜치가 기준본**입니다.

- 공개 링크: https://gustjrwjs.github.io/Sports-Dashboard/static/
- 저장소: https://github.com/gustjrwjs/Sports-Dashboard (GitHub Pages: main / root)
- 소유자와는 **한국어**로, 쉬운 말로 대화합니다.

## 📋 다음 할 일 (소유자가 요청함 · 묻지 말고 순서대로 진행, 끝나면 이 목록에서 지우기)

1. (선택) 지난 시즌 메뉴에서 ESPN에 데이터가 없는 시즌 숨기기 — 지금은 고르면 "기록이 없습니다" 안내.
2. (보류 · 소유자 결정 2026-11-13) K리그·KBO·NPB 정식 추가: API-Sports 키 발급 완료(GitHub Secret `API_FOOTBALL_KEY`, 축구·야구 같은 키). 확인 결과 Free 플랜은 2022~2024 시즌만 접근 가능(2026 요청 시 "Free plans do not have access to this season"), 축구·야구 한도 각각 하루 100회. 리그 번호: K리그1=292, K리그2=293(부상 데이터 없음), KBO=5, NPB=2. 유료(Football Pro 약 $19, Baseball Pro 약 $15) 결제하면 GitHub Actions로 하루 1~2회 받아 `static/data/*.json`에 저장하는 방식으로 연결 예정.
3. (참고, 소유자가 원하면) ESPN에 있는 아시아 리그: AFC 챔피언스리그(`afc.champions`, K리그 팀 출전), J리그(`jpn.1`), 사우디(`ksa.1`), A리그(`aus.1`), 중국(`chn.1`).

완료(2026-11-12): EFL 챔피언십(`eng.2`) 추가, K리그1·2·NPB "준비 중"(ESPN `baseball` 리그 12개에 NPB 없음, `jpn.npb`/`npb` 빈 응답), 대진표 미리보기.

대진표 미리보기(`buildPlan`·`planResolve`·`renderPlan`): 확정 전에는 현재 순위로 채운 **예상 대진**(점선 칸, "확정되면 업데이트")을 보여주고, 실제 경기가 생기면 팀 id로 찾아 그 자리를 실제 대결로 교체(5분마다 재확인). 순위로 대진이 정해지는 대회(`FIXED_BR`: NBA·MLB·MLS·승격 PO)는 끝날 때까지 이 방식, 추첨 대회(챔스·유로파·네이션스리그)는 본선 대진이 나오면 실제 대진표 + 남은 라운드 빈칸. 챔피언십은 2026-27부터 6팀 PO(5v8·6v7 엘리미네이터 → 3위는 남은 팀 중 낮은 순위와 준결승 → 웸블리 결승). ESPN이 MLS를 다음 시즌 연도로 넘겨도 지난 연도 PO가 진행 중이면 그걸 씀(`ongoing`).

완료(2026-11-13): 농구 경기 전 예상 선발·명단(`fillBbPre`), CONCACAF 네이션스리그(`cnl`, `isNL()`로 UNL과 공용), 경기 검색(`openSearch`), 미니 라이브 PiP(`openPip`, Document PiP → 안 되면 `#pipbox`), 베팅내역 캡처 인식(`importSlips`: Tesseract.js 5.1.1 jsdelivr에서 필요할 때만 로드, 3배 확대·흑백 전처리, 같은 줄의 두 팀만 짝짓기, 한 글자 차이 표기 허용). 세 기능 모두 `loadIndex()`(전체 리그 이번 달 경기 목록) 공용.
- 쿼터·이닝별 점수표 `periodTable()`(LIVE 카드·My·경기 상세 공용). 휴대폰은 붙여넣기 칸을 누르면 바로 갤러리(사진 선택) 열림(`TOUCH`).
- PiP 창 위의 주소 바·창 틀, 창 투명도는 브라우저(OS 창)가 정하는 것이라 웹에서 못 바꿈 — 소유자에게 설명함.
- 문자중계 `pbpBuild`(축구 commentary·keyEvents / 농구·야구 plays → 한국어 템플릿, `pickT`로 장면마다 고정 멘트), 카드 위 초록 한 줄 `pbpTicker`(작은 장면 low는 뒤로), 상세 창 `pbpSection` + `pbpLoop` 20초 갱신. AI 챗봇 중계는 키 숨길 서버 필요해서 보류.
- 국가대표 친선경기 `intfr`(ESPN `fifa.friendly`, `nostand:true` → 순위표 탭 숨김·팀 분석은 이번 주 경기 팀). FIFA 랭킹 `loadFifa()`: 위키백과 `Module:SportsRankings/data/FIFA_World_Rankings`를 api.php `origin=*`(CORS)로 받음. FIFA 공식 API는 CORS 없음·봇 차단이라 쓰지 않음. 팀 이름 맞추기 `fnorm` + 모듈의 코드 별칭 + `FIFA_EXTRA`.
- 축구 경기 상세 `fillSoccerIntel`: 주목할 선수 = summary.leaders(득점·도움·슈팅·선방 팀 내 1위), 결장 의심 = 최근 4경기 라인업 비교(이전 3경기 중 2선발 이상인데 직전 경기 미출전 → 명단 제외/벤치, 직전 퇴장 → 출장정지 가능). ESPN은 축구 부상 데이터가 사실상 없음(경기 전·후 summary.injuries 빈 값 확인).
- 홈 탭 `renderHome`(첫 화면, 주소에 리그 없으면 홈): `loadIndex()` 목록에서 오늘(기기 날짜) + 진행 중. 종목·상태 필터, 내 경기·진행 중·곧 시작(`countdown`)·리그별 묶음. 홈에선 `#lgbar` 숨김, 리그 버튼 누르면 순위표로. My 경기 선택/전체 삭제 `data-myact`.
- 응원팀 `FAVS`(favTeams.v1, `favBtn`/`favCard`), 알림 `NOTI`(noti.v1, 기본 off, `notiTick` 30초: My+응원팀 경기 점수 스냅샷 비교 → `pushNoti`(SW showNotification, sw.js notificationclick)), 빅매치 `loadBig`(리그 순위·FIFA·승률), 예측 `PICKS[].bet` + `BETLOG`(betLog.v1, `gradeBets`, 홈 `betStats`).
- 메뉴 2단: 맨 위 `#gnav`(홈·리그·My·커뮤니티, 항상) / 리그 화면(`LG_TABS` 순위표·일정·팀 분석·LIVE)에서만 `#lghead`·`#lgbar`·`#tabs`. 리그 버튼은 마지막 리그 탭(`S.lastLgTab`) 기억.
- My 묶음: `PICKS[].grp`(기본 1), 빈 묶음 `MYGRPS`(my.groups), ☆ 담기 대상 `addGrp()`(my.addGrp = 마지막으로 고른 묶음), 새 번호 `freeGrps`(빈 가장 작은 번호), 삭제 후 `renumberGrps`. 캡처는 파일마다 따로 OCR → 파일마다 새 묶음.
- 컵대회 `facup`(eng.fa)·`dfbpokal`(ger.dfb_pokal)·`copadelrey`(esp.copa_del_rey)·`coppaitalia`(ita.coppa_italia): `cup:true`+`nostand` → 순위표 탭이 "🏆 대진표"(BR kind `cup`: 16강/FA컵 5라운드~결승), 일정은 `months:CUP_MONTHS`(8월~다음 해 5월). 두 팀 다 TBD인 경기는 대진표에서 제외. ESPN standings 응답 시즌은 `seasonOfResp`(seasons 배열/season 단수/빈 객체).
- 기기 연동 `SYNC`(sync.code/sync.t): Supabase RPC `sync_get`/`sync_put`(supabase_sync.sql, 코드 해시를 키로 JSON 저장). 저장 함수들이 `syncDirty()` → 2초 뒤 push, 앱 열 때·다시 볼 때·1분마다 pull. 마지막 변경 기기 우선(전체 덮어쓰기), 처음 연결 때만 `mergeSync`. QR(qrcode-generator 1.4.4 jsdelivr) 주소 `#sync=코드`. 알림 설정은 기기별.
- My 보기 `S.myView`(my.view, 기본 list) → `myTable()` 한 줄 표, 배당 버튼이 예측(`data-bet`). 클래스 `.oc`는 기존 배당 칩과 겹쳐서 표는 `.moc`.
- 한 줄 표 "중계" 칸(`td.mtx`): 진행 중 = `pbpLatest(k)` 최근 장면, 예정 = 3시간 안이면 카운트다운. 멘트는 상황별(중거리·헤더·PK·멀티골/해트트릭·극장골·동점/역전·쐐기, 클러치·20/30/40점 돌파·런, 만루홈런·초대형 등) 여러 개 중 `pickT`로 고정 선택.
- 라이브스코어 용어는 **중계 멘트(문자중계·중계 칸)에만** 씀. 점수·상태 표시(경기 종료·하프타임·NQ 종료)는 공식 표현 유지(소유자 요청). 멘트 전시/후시/전종/후종/경종·선제골/추격골/동점골/역전골/쐐기골·승부차기, 농구 앤드원·버저비터·연장, 야구 솔로포/투런/스리런/만루포·적시타·희플·병살·KKK·끝내기.
- My 표의 ☆는 왼쪽 첫 칸(sticky left, 소유자 요청), 카드 머리줄도 ☆ 왼쪽. 문자중계 추가 용어: 추가골/만회골/대승·전반 노골·N명으로 싸움, 앤드원·버저비터·더블더블/트리플더블·3점 폭격·클러치 자유투 실패, 백투백·빅이닝·도루/홈스틸·포볼/데드볼, 공통 `pbpExtras`(언오버 오버 확정 + 경종 요약: 홈승/원정승·정배/역배·오버/언더·클린시트/완봉·결승골·대승).
- 캡처 이미지는 **절대 서버·저장소로 보내거나 저장하지 않음**(화면에 명시됨, 소유자 요청). 이 원칙 유지.

참고: 지난 시즌 데이터는 `S.season` + `D()`가 `"리그@연도"` 칸을 따로 씀(`dkeyOf`). ESPN이 지난 시즌 standings에 현재 시즌 이름·시작일을 붙여 보내므로 `applyStandings`에서 덮어씀.

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
