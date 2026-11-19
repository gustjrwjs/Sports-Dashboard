# SPORTS LIVE! 기능별 상세 메모

> CLAUDE.md에서 옮김(2026-11-14, 토큰 절약). **고칠 기능이 있을 때 그 부분만 찾아 읽기** (예: `grep -n "회원" docs/FEATURES.md`).

완료(2026-11-12): EFL 챔피언십(`eng.2`) 추가, K리그1·2·NPB "준비 중"(ESPN `baseball` 리그 12개에 NPB 없음, `jpn.npb`/`npb` 빈 응답), 대진표 미리보기.

대진표 미리보기(`buildPlan`·`planResolve`·`renderPlan`): 확정 전에는 현재 순위로 채운 **예상 대진**(점선 칸, "확정되면 업데이트")을 보여주고, 실제 경기가 생기면 팀 id로 찾아 그 자리를 실제 대결로 교체(5분마다 재확인). 순위로 대진이 정해지는 대회(`FIXED_BR`: NBA·MLB·MLS·승격 PO)는 끝날 때까지 이 방식, 추첨 대회(챔스·유로파·네이션스리그)는 본선 대진이 나오면 실제 대진표 + 남은 라운드 빈칸. 챔피언십은 2026-27부터 6팀 PO(5v8·6v7 엘리미네이터 → 3위는 남은 팀 중 낮은 순위와 준결승 → 웸블리 결승). ESPN이 MLS를 다음 시즌 연도로 넘겨도 지난 연도 PO가 진행 중이면 그걸 씀(`ongoing`).

완료(2026-11-13): 농구 경기 전 예상 선발·명단(`fillBbPre`), CONCACAF 네이션스리그(`cnl`, `isNL()`로 UNL과 공용), 경기 검색(`openSearch`), 미니 라이브 PiP(`openPip`, Document PiP → 안 되면 `#pipbox`), 베팅내역 캡처 인식(`importSlips`: Tesseract.js 5.1.1 jsdelivr에서 필요할 때만 로드, 3배 확대·흑백 전처리, 같은 줄의 두 팀만 짝짓기, 한 글자 차이 표기 허용). 세 기능 모두 `loadIndex()`(전체 리그 이번 달 경기 목록) 공용.
- 쿼터·이닝별 점수표 `periodTable()`(LIVE 카드·My·경기 상세 공용). 휴대폰은 붙여넣기 칸을 누르면 바로 갤러리(사진 선택) 열림(`TOUCH`).
- PiP 창 위의 주소 바·창 틀, 창 투명도는 브라우저(OS 창)가 정하는 것이라 웹에서 못 바꿈 — 소유자에게 설명함.
- 문자중계 `pbpBuild`(축구 commentary·keyEvents / 농구·야구 plays → 한국어 템플릿, `pickT`로 장면마다 고정 멘트), 카드 위 초록 한 줄 `pbpTicker`(작은 장면 low는 뒤로), 상세 창 `pbpSection` + `pbpLoop` 20초 갱신. AI 챗봇 중계는 키 숨길 서버 필요해서 보류.
- 국가대표 친선경기 `intfr`(ESPN `fifa.friendly`, `nostand:true` → 순위표 탭 숨김·팀 분석은 이번 주 경기 팀). FIFA 랭킹 `loadFifa()`: 위키백과 `Module:SportsRankings/data/FIFA_World_Rankings`를 api.php `origin=*`(CORS)로 받음. FIFA 공식 API는 CORS 없음·봇 차단이라 쓰지 않음. 팀 이름 맞추기 `fnorm` + 모듈의 코드 별칭 + `FIFA_EXTRA`.
- 축구 경기 상세 `fillSoccerIntel`: 주목할 선수 = summary.leaders(득점·도움·슈팅·선방 팀 내 1위), 결장 의심 = 최근 4경기 라인업 비교(이전 3경기 중 2선발 이상인데 직전 경기 미출전 → 명단 제외/벤치, 직전 퇴장 → 출장정지 가능). ESPN은 축구 부상 데이터가 사실상 없음(경기 전·후 summary.injuries 빈 값 확인).
- 홈 탭 `renderHome`(첫 화면, 주소에 리그 없으면 홈): `loadIndex()` 목록에서 오늘(기기 날짜) + 진행 중. 종목·상태 필터, 내 경기·진행 중·곧 시작(`countdown`)·리그별 묶음. 홈에선 `#lgbar` 숨김, 리그 버튼 누르면 순위표로. My 경기 선택/전체 삭제 `data-myact`.
- 응원팀 `FAVS`(favTeams.v1, `favBtn`/`favCard`), 알림 `NOTI`(noti.v1, 기본 off, `notiTick` 30초: My+응원팀 경기 점수 스냅샷 비교 → `pushNoti`(SW showNotification, sw.js notificationclick)), 빅매치 `loadBig`(리그 순위·FIFA·승률), 예측 `PICKS[].bet` + `BETLOG`(betLog.v1, `gradeBets`, 홈 `betStats` — 오늘·최근 7일·전체 + 종목별 ⚽🏀⚾, 모두 승패·언오버 합산(소유자 요청)).
- 머리글(header.top)은 고정하지 않음(스크롤하면 같이 올라감, 소유자 요청). 메뉴 2단: 맨 위 `#gnav`(홈·리그·My·커뮤니티, 항상) / 리그 화면(`LG_TABS` 순위표·일정·팀 분석·LIVE)에서만 `#lghead`·`#lgbar`·`#tabs`. 리그 버튼은 마지막 리그 탭(`S.lastLgTab`) 기억.
- My 묶음: `PICKS[].grp`(기본 1), 빈 묶음 `MYGRPS`(my.groups), ☆ 담기 대상 `addGrp()`(my.addGrp = 마지막으로 고른 묶음), 새 번호 `freeGrps`(빈 가장 작은 번호), 삭제 후 `renumberGrps`. 캡처는 파일마다 따로 OCR → 파일마다 새 묶음.
- 컵대회 `facup`(eng.fa)·`dfbpokal`(ger.dfb_pokal)·`copadelrey`(esp.copa_del_rey)·`coppaitalia`(ita.coppa_italia): `cup:true`+`nostand` → 순위표 탭이 "🏆 대진표"(BR kind `cup`: 16강/FA컵 5라운드~결승), 일정은 `months:CUP_MONTHS`(8월~다음 해 5월). 두 팀 다 TBD인 경기는 대진표에서 제외. ESPN standings 응답 시즌은 `seasonOfResp`(seasons 배열/season 단수/빈 객체).
- 기기 연동 `SYNC`(sync.code/sync.t): Supabase RPC `sync_get`/`sync_put`(supabase_sync.sql, 코드 해시를 키로 JSON 저장). 저장 함수들이 `syncDirty()` → 2초 뒤 push, 앱 열 때·다시 볼 때·1분마다 pull. 마지막 변경 기기 우선(전체 덮어쓰기), 처음 연결 때만 `mergeSync`. QR(qrcode-generator 1.4.4 jsdelivr) 주소 `#sync=코드`. 알림 설정은 기기별.
- My 보기 `S.myView`(my.view, 기본 list) → `myTable()` 한 줄 표, 배당 버튼이 예측(`data-bet`). 클래스 `.oc`는 기존 배당 칩과 겹쳐서 표는 `.moc`.
- 한 줄 표 "중계" 칸(`td.mtx`): 진행 중 = `pbpLatest(k)` 최근 장면, 예정 = 3시간 안이면 카운트다운. 멘트는 상황별(중거리·헤더·PK·멀티골/해트트릭·극장골·동점/역전·쐐기, 클러치·20/30/40점 돌파·런, 만루홈런·초대형 등) 여러 개 중 `pickT`로 고정 선택.
- 라이브스코어 용어는 **중계 멘트(문자중계·중계 칸)에만** 씀. 점수·상태 표시(경기 종료·하프타임·NQ 종료)는 공식 표현 유지(소유자 요청). 멘트 전시/후시/전종/후종/경종·선제골/추격골/동점골/역전골/쐐기골·승부차기, 농구 앤드원·버저비터·연장, 야구 솔로포/투런/스리런/만루포·적시타·희플·병살·KKK·끝내기.
- My 표의 ☆는 왼쪽 첫 칸(sticky left, 소유자 요청), 카드 머리줄도 ☆ 왼쪽. 문자중계 추가 용어: 추가골/만회골/대승·전반 노골·N명으로 싸움, 앤드원·버저비터·더블더블/트리플더블·3점 폭격·클러치 자유투 실패, 백투백·빅이닝·도루/홈스틸·포볼/데드볼, 공통 `pbpExtras`(언오버 오버 확정 + 경종 요약: 홈승/원정승·정배/역배·오버/언더·클린시트/완봉·결승골·대승).
- 중계 멘트 토토·라스 은어(소유자 제공 블로그 기준): ㅅㅅㅅㅅ(골)·옵사/옵취·비판(VAR)·추시·새축(새벽 킥오프)·전두언(전반 2골)·후3옵(후반 3골)·옵퇴근/언더퇴근·마핸/플핸/핸무·무과장·적특, 야구 공교·웃ㅅㅅ·타ㅌㅌㅌ·큰거 ㄷㄷㄷㄷ·볼질/괴볼·희플·타득·393(같은 atBatId 투구 3개·볼 0)·좌플웃/우플웃.
- 놀리는 은어도 중계 멘트에 넣음(소유자 요청): 개리그(0:0 전종·경종, 런 당한 팀), 똥볼(하늘로 뜬 슛·PK 실축), 팀킬(자책골), 자동문·물수비(3골 차), 똥손·벽돌(자유투 0/2), 턴오버 참사(클러치), 가비지 타임(4Q 25점 차), 알까기(실책), 방화(빅이닝). 토사장·진중/구중은 경기 상황과 무관해 제외.
- 화면 밸런스(2026-11-13 점검): 작은 경기 카드 `miniRow`는 가운데 칸에 점수/시간 + 그 아래 상태(종료·● 시간·남은 시간), 홈 리그 묶음 안은 `compact`(리그 줄 생략, ☆ 오른쪽). 휴대폰: 리그 버튼 한 줄 가로 스크롤(고른 리그 자동 맞춤), 경기 상세 머리 가운데 칸 좁게·팀 이름 2줄, 배당표 좁게, 일정 카드 '홈' 표시 숨김, My 버튼 짧은 글자.
- 캡처 이미지는 **절대 서버·저장소로 보내거나 저장하지 않음**(화면에 명시됨, 소유자 요청). 이 원칙 유지.

- 광고 자리 `ADS`/`adSlot(name)`(기본 꺼짐 → 빈 문자열). 자리: home(오늘 일정 리그 3개 뒤)·league(순위표 범례 아래)·matches(일정 둘째 날 뒤)·detail(경기 상세 중계·라인업 뒤, 두 팀 비교 앞)·my(My 맨 아래). `?adtest`로 노란 점선 미리보기. 켜려면 `ADS.on/client/slots` + `<head>`에 애드센스 스크립트. PiP·검색·캡처 창·배당 버튼 옆·글쓰기 창엔 넣지 않음.

- 게시판 📌 공지 고정: `posts.pinned` + RPC `admin_pin_post`(운영자 비밀번호를 서버가 확인, supabase_pin.sql). 목록은 `pinned.desc,created_at.desc`. pinned 칸이 없으면(`TK.pinOk=false`) 고정 없이 불러오고 버튼 숨김.

- 영어 이름 → 한국어 발음 표기(2026-11-13 완료): `hangul(name, en)` 규칙 변환기(사전 `HG_WORD` → 글자를 소리 조각으로 `hgPhones` → 음절 조립 `hgWord`, 메모 `HG_MEMO`). `en` true=영어식(농구·야구, `enSport()`), false=라틴식, 생략=단어마다 `looksEn`으로 자동. `ko()`(팀)·`koFull`/`koShort`(선수, 위키데이터 없을 때)에 적용. **경기장 이름은 영어 그대로**(2026-11-14 소유자 요청), 경기 카드 경기장 줄은 점수 칸 기준 가운데(`.mvenue` grid-column 2/-1). 상태 `stKo`(Final→종료, Canceled→취소 등)·메모 `mnoteKo`(1st Leg→1차전)·DNP 사유 한국어. 이상한 표기는 `HG_WORD`에 단어 추가로 고침.

- 홈 어제·오늘·내일(2026-11-13 완료): `renderHome`이 기기 날짜 기준 -1~+1일(`offOf`) + 진행 중을 모음. 날짜 칩 `data-hday`(3일 전체·어제·오늘·내일, `S.homeDay`), 일정은 날짜별 테두리 상자 `.dayp`(오늘=파란 테두리, 오늘 → 내일 → 어제) 안에 **리그 섞어 시간순 한 줄** `lsRow`(시간·상태 | 종목 공 ⚽🏀⚾ `.lsp` | 리그 표시 | 홈 | 점수 | 원정 | ☆, 진행 중 → 예정 → 종료(맨 아래) 순, `STO`). 휴대폰(≤640px)은 `.lmb`로 두 팀 위아래 두 줄 + 점수 오른쪽(소유자 요청: 리그별 묶음이 난잡). 진행 중 경기는 오늘로 침. `loadIndex`는 1~2일엔 지난달, 19일 이후엔 다음 달도 받음.

- 📊 경기 기록(2026-11-13 완료): `statsSection`(summary `boxscore.teams[].statistics`, 종목별 항목 `ST_DEF`, 야구는 `batting.H`처럼 분류.약자). 홈 파랑(--accent)·원정 주황 양쪽 막대, 큰 값 굵게. 진행 중이면 `pbpLoop`가 20초마다 `#stsec` 교체. 야구 LOB(잔루)는 ESPN 값이 누적이라 뺌.

- 🆚 상대 전적(2026-11-13 완료): 팀 일정 맞대결 + `seriesEvents(sum)`(summary `seasonseries`: 축구 최근 5번 맞대결(지난 시즌 포함)·NBA/MLB 시즌 시리즈) 합침(날짜+팀 쌍으로 중복 제거, id 체계가 달라서). `h2hSummary` 승무패·평균 득실·합계·2.5 오버·양팀 득점·이번 기준점 오버. 두 팀 비교에 '이번 기준점(라인) 오버 n/5' 줄(축구 2.5면 생략).

- ● 실시간 순위(2026-11-13 완료): `liveGroups`가 `D().matches` 중 진행 중 경기 점수를 순위표 행에 더해(축구 승점·득실, 농구·야구 승패·승률) 다시 정렬, `r.delta`로 ▲▼, 경기 중 팀 옆 `● 득:실`. 지난 시즌 보기에선 안 함. 게임차(gb)는 다시 계산 안 함.

- 🏆 예측 랭킹(2026-11-13 코드 완료): `supabase_rank.sql` — 표 `preds`(직접 읽기·쓰기 불가), RPC `pred_put`(시작 전만·닉네임 사칭·주소 형식 검사, 1분 40회 제한)·`pred_rank`(주간 상위 20 + 내 줄). 채점은 서버가 pg_cron 10분마다 `pred_collect`→`pred_fetch`(pg_net으로 ESPN summary) → 시작 시간(ESPN 값) 뒤 변경은 void. 앱: `RANK`(rank.on), 랭킹 전용 비밀값 `rankSecret()`(rank.sec, 기기 연동 `syncState().rank`로 이어짐), `setBet`의 승패 예측 → `predPush`, 홈 `rankCard`(SQL 없으면 숨김), 주 = 월요일 0시 KST(`weekRange`). 로컬 PostgreSQL 16 + net/cron 흉내로 SQL 검증함.

- ▶ 하이라이트(2026-11-13 완료): 종료 경기 상세 머리 아래 `hlLinks` — 유튜브 검색 링크만(한국어 팀명 + "하이라이트" / 영어 팀명 + highlights 연도). 영상 삽입·저장 없음.

- 👤 회원(2026-11-13 코드 완료): `supabase_account.sql` — 아이디(영소문자·숫자·_ 4~16)+비밀번호(6~72, bcrypt, 소유자 요청으로 6자) 가입, 이메일 없음(비번 분실 시 복구 불가 안내). 표 `accounts`(data jsonb = 기기 연동과 같은 `syncState()`)·`acc_tokens`(토큰 sha256, 180일). RPC `acc_signup`·`acc_login`(틀리면 예외 대신 {error} 반환 → 틀린 횟수 기록 유지, 10번 틀리면 15분 잠금)·`acc_get`·`acc_put`(300KB)·`acc_logout`·`acc_nick`·`acc_passwd`(다른 기기 토큰 삭제)·`acc_delete`. 앱: `ACC`(acc.tok/uid/nick), 머리글 👤 `#accBtn`→`openAcc`, 로그인하면 코드 연동 끄고 `syncPush/syncPull`이 acc_put/acc_get 사용, 첫 로그인 때 `mergeSync`로 합침, 닉네임은 게시판 닉네임(tk.nick)과 같게. My의 연동 버튼은 `syncBtn()`. 로컬 PostgreSQL로 SQL 검증함.

- 🛡 운영자 계정(2026-11-13): `accounts.is_admin`, `sl_is_admin(p_pass)`를 "운영자 비밀번호 OR 운영자 계정 토큰"으로 재정의(supabase_account.sql 안, setup.sql 다시 돌리면 account.sql도 다시), `acc_make_admin(token, 운영자비번)`. 앱 `ACC.admin`(acc.admin, acc_login/acc_get의 admin), `adminPass()`가 운영자 계정이면 토큰을 돌려줘 고정·답변·삭제가 비번 없이 됨. 머리글 버튼 🛡(`#accBtn.isadm` — `.adm`은 게시판 '운영자 모드' 배지 클래스라 겹치지 않게).

- 선수 이름 순서(2026-11-13 소유자 요청: 위키백과 이름 그대로, 한국 선수 제대로): `koFull` = 위키데이터 한국어 이름(한국어 레이블/한국어 위키백과 제목) → `krName`(한국 선수 영어 표기 되돌리기: 성 `KR_SUR` + 이름 음절 `KR_SYL`, 붙여 쓴 이름은 `krSplit`, 성 앞/뒤 둘 다, 예 Jung Hoo Lee→이정후) → `hangul`. 위키데이터 조회는 대소문자·악센트 다른 표기도 같이 물음(Son Heung-Min ↔ Son Heung-min), 502면 한 번 재시도, `wd()`는 다른 종목 조회 결과도 확인. 캐시 키 `wdPlayers.v3`.

- 배당 '현재' 문구(2026-11-13): 계산은 그대로, 진행 중은 `지금 무승부/홈 리드`, 핸디 `지금 홈 +0.5 적중`, 언오버 `ouNow` = `지금 0골 · 언더 (3골 더 나면 오버)`(필요 = floor(기준-합계)+1), 축구는 '골' 단위. 결장 의심은 이 경기 라인업이 나오면 `applyLu`로 반영(선발·교체 투입 → 목록에서 뺌, 벤치 → '이 경기 벤치', 명단에 없음 → '이 경기 명단 제외(확정)').

- ▲ 맨 위로(2026-11-14 소유자 요청: 스크롤 긴 모든 페이지): `updateFab`의 `#fabTop`은 모든 탭에서 300px 넘게 내리면 보임(📅 오늘 `#fabToday`는 경기 일정 탭만). 경기 상세 등 창(`#modal`)은 안쪽 `#mtop`(sticky, 400px 넘게 내리면 `.scrolled`).

- My 붙여넣기 칸 위 직접 검색(2026-11-14 소유자 요청): `.impsearch` — 담을 묶음 칩 `drawIsGrp`(`data-isg`, ＋ 새 묶음 = `newGrp()`, 고른 묶음은 my.addGrp = ☆ 담기와 같은 대상) + 입력 `#impq` → `impSearch`(loadIndex에서 진행 중·2주 안 예정, 최대 8개) → `data-isadd`로 `addPickFrom(lg, m, addGrp())`.

- 따라오는 얇은 메뉴(2026-11-14 소유자 요청): 머리글은 그대로 고정 안 함, 대신 `#sbar`(fixed) = 로고 + `#gnav` 복제 + 리그 화면이면 `#tabs` 복제. 원래 메뉴(탭 있으면 #tabs, 없으면 #gnav)가 화면 위로 나가면 `.show`(`sbarShow`). `syncSbar`는 화면 갱신 때 + MutationObserver(배지 숫자·선택)로 다시 그림, 버튼은 같은 data-gnav/data-tab 위임 처리. 보일 때 `scroll-padding-top` 설정.

- 카톡 등 앱 안 브라우저(2026-11-14 소유자 요청: 카톡 공유 시 앱 설치 안 됨): `<head>` 맨 앞 스크립트가 카카오톡이면 `kakaotalk://web/openExternal?url=`(카카오 공식)로 바깥 브라우저 열기, LINE은 `openExternalBrowser=1`. 그래도 남은 경우·네이버·인스타 등은 노란 안내 띠 `#inappbar`(안드로이드 = Chrome intent 링크, 아이폰 = Safari로 여는 법 + 주소 복사). 공유 미리보기 og:title/description/image(icon-512) 추가. 휴대폰(≤480px) 머리글 '앱 설치'는 📲 동그란 버튼, ≤420px에선 📺·↻ 숨김(자동 갱신 있음).

참고: 지난 시즌 데이터는 `S.season` + `D()`가 `"리그@연도"` 칸을 따로 씀(`dkeyOf`). ESPN이 지난 시즌 standings에 현재 시즌 이름·시작일을 붙여 보내므로 `applyStandings`에서 덮어씀.

- 리그 ● 빨간 점(2026-11-15 소유자 요청): `lgLiveDots` — IDX(전체 리그 목록)에서 진행 중 경기가 있는 리그 칩 `.lgc.haslive`·종목 버튼(`data-sgk`)에 빨간 점, 1분마다. 경기 카드 경기장 줄: 4칸 카드는 grid-column 2/-1, 3칸(`.nogrp`·`.strip`)은 1/-1.

- 팀 분석 최근 경기·맞대결 줄 누르면 경기 상세(`resList` → `EVX` 보관, `findMatch`가 마지막에 찾음). 리그 탭 순서: 경기 일정이 맨 앞·기본(`LG_TABS`).
- 팝업(#modal) 열려 있을 때 뒤 페이지 스크롤 잠금: CSS `html:has(dialog[open])` overflow hidden + `dialog{overscroll-behavior:contain}`.
- 따라오는 줄(#sbar) LIVE 옆 리그 선택 상자(`sbarLgSel`, `#sblgSel`, 종목별 묶음, ● 진행 중). 고르는 중엔 줄을 다시 그리지 않음.
- 경기 일정 카드·홈 줄 작은 배당 표(`oddsMini`/`oddsCell`, 보이는 경기만 summary로 받음 `oddsObserve`·`oddsPump`, 끝난 경기는 localStorage `oddsc.v1`). 역배 적중 = 끝난 경기에서 배당 높은 팀 승리 → 팀 이름에 빨간 네모 + "역"(`yeokSide`, `.tn.yk`, 이름은 `.tn>.tnx`). PC: 승무패+언오버 표, 휴대폰: 승무패 한 줄(카드는 경기장 줄 자리, 홈은 팀 이름 아래).
- 팀 일정(`teamData`, scope all): 시즌 끝난 봄~가을 리그(MLS)는 ESPN 기본이 다음 시즌이라 지난 경기 0개 → `?season=올해/작년`으로 다시 받음.
- My 경기 묶음별 중복 담기: 담은 항목 키 = 리그|경기|묶음(`pk`). ☆는 지금 담는 묶음 기준 담기/빼기(`togglePick(lg,id,grp)`), My 화면 별·선택·예측(`data-bet`, `setBet(sk)`)은 항목별. 예측 적중 표시는 그 묶음의 예측으로 계산. 캡처 담기는 다른 묶음에 있어도 담김.
