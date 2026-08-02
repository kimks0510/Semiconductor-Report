# Claude 인수인계서 — Semiconductor Daily Report 자동화

작성 기준일: 2026-08-02 (Asia/Seoul)  
프로젝트 경로: `C:\Workspace\Semiconductor_Daily_Report`

## 1. 한눈에 보는 현재 상태

이 프로젝트는 반도체 일일 브리핑을 Codex CLI로 생성하고, GitHub Pages에 게시한 뒤 카카오톡 **나에게 보내기**로 요약 4건을 보내는 파이프라인이다. 보고서 생성·GitHub 게시·카카오 API 발송은 PC가 깨어 있고 Codex 및 네트워크가 정상일 때 실제로 성공했다.

그러나 다음 두 가지 핵심 요구는 아직 해결되지 않았다.

1. 전원 버튼을 한 번 눌러 진입한 Modern Standby 상태에서 Windows 예약 작업이 PC를 정해진 시각에 확실히 깨우지 못했다.
2. 카카오 발송 시각이 08:00으로 고정되지 않고 오후나 저녁으로 밀린다. 현재 구현은 **08:00 발송 예약**이 아니라 **08:00 보고서 생성 시작 후 모든 작업이 끝나는 즉시 발송**하는 구조이며, 절전 중 프로세스 정지·Codex 장시간 실행·누락 작업 재개가 겹치면 실제 발송도 그만큼 늦어진다.

확인된 사실과 아직 검증하지 못한 가설을 혼동하지 말아야 한다. 특히 현재 비관리자 세션에서는 `Get-ScheduledTask`가 `액세스가 거부되었습니다`를 반환해, 작업 스케줄러에 지금 실제로 등록된 최종 설정은 확인하지 못했다.

## 2. 원하는 최종 동작

- 평일 07:50: 절전 상태의 PC를 깨우고 보고서 생성 중 다시 잠들지 않도록 유지
- 평일 08:00: 반도체 보고서 생성 시작
- 생성 성공 후: GitHub Pages 게시 및 카카오톡 나에게 보내기
- 08:20 이후: 대한항공 보고서는 반도체 보고서 종료를 확인한 뒤 실행
- 실패 시: `output/errors.log`에 원인을 남기고 중복 발송 없이 재시도
- 완전 종료 상태에서는 Windows 작업 스케줄러만으로 실행할 수 없음을 전제로 함

중요한 제품 결정이 아직 필요하다. 뉴스 검색과 장문의 생성은 소요 시간이 고정되지 않으므로 **08:00 정각 발송**과 **08:00 최신 뉴스 수집 시작**을 동시에 보장할 수 없다. 정각 발송이 필수라면 전날/더 이른 시각에 미리 생성하거나, 상시 켜진 서버·GitHub Actions 등으로 실행 환경을 옮겨야 한다.

## 3. 현재 파이프라인

```text
07:50 Daily Report Wake Guard (SYSTEM)
  -> Keep-SystemAwakeForReports.ps1가 10:30까지 시스템 절전 방지 요청

08:00 Semiconductor Daily Report
  -> Run-DailyReport.ps1
  -> codex exec로 output/YYYY-MM-DD-briefing.md 생성 (최대 3회)
  -> Build-MobileSite.ps1 및 git commit/push
  -> Send-KakaoBriefing.ps1로 카카오 메시지 4건 전송

08:20 Korean Air Daily Scrap
  -> 반도체 SUCCESS 로그를 최대 2시간 기다림
  -> 별도 보고서 생성·게시·카카오 발송
```

카카오 발송 스크립트 자체에는 예약 시각 개념이 없다. `Run-DailyReport.ps1`의 GitHub 게시가 끝난 직후 API를 호출한다.

## 4. 주요 파일 지도

| 파일 | 역할 | 현재 주의점 |
|---|---|---|
| `AGENTS.md` | 반도체 뉴스 수집·보고서 형식·평일 08:00 요구사항 | 자동화 구현과 일부 불일치 |
| `scripts/Run-DailyReport.ps1` | 생성 → 게시 → 카카오 전송의 메인 러너 | 동시 실행 잠금, 단계별 체크포인트, 전체 타임아웃 진단이 없음 |
| `scripts/Register-DailyTask.ps1` | 08:00 작업 등록 | `Daily`라 주말도 실행; Principal이 명시되지 않음 |
| `scripts/Register-AllDailyReports.ps1` | wake timer 전원 정책과 3개 작업 등록 | 관리자 권한 필요 |
| `scripts/Register-ReportWakeGuard.ps1` | 07:50 SYSTEM wake guard 등록 | 역시 `Daily`; 실제 wake 성공은 미검증 |
| `scripts/Keep-SystemAwakeForReports.ps1` | 실행 후 10:30까지 절전 방지 | 이미 잠든 PC를 스스로 깨우지는 못함 |
| `scripts/Send-KakaoBriefing.ps1` | Kakao Summary 3건 + 전체 보고서 링크 1건 발송 | 호출할 때마다 같은 보고서를 다시 보냄; idempotency 없음 |
| `scripts/KakaoCommon.ps1` | 토큰 읽기·refresh | 사용자 환경변수와 `.secrets/kakao-token.json`에 의존 |
| `scripts/Publish-GitHub.ps1` | 모바일 사이트 빌드, commit, push | push가 끝나야 카카오 발송 단계로 진행 |
| `scripts/Register-DynamicWakeTrial.ps1` | 단발성 wake 검증 작업 등록 | 7월 25일 첫 시험은 예약 wake 실패 |
| `output/2026-07-25-sleep-trial-analysis.md` | 첫 절전 시험 분석 | 파일 인코딩이 깨져 보여 재작성 필요 |
| `output/run-*.log` | 반도체 실행 단계별 로그 | 프로세스가 정지/종료되면 마지막 줄 이후 원인을 알 수 없음 |
| `output/kakao-send.log` | 성공한 카카오 API 호출 시각 | 메시지 단위가 아니라 배치 완료 1줄만 기록 |
| `output/errors.log` | 일부 실패 기록 | 모든 비정상 종료를 포착하지 못함 |

별도 하위 프로젝트 `Korea_Airline_Scrap`도 같은 Codex CLI·GitHub·카카오 자원을 사용한다. 동시 실행과 Git 충돌을 피하려고 반도체 성공을 최대 2시간 기다리지만, 2시간이 지나면 독립 실행한다.

## 5. 실제 작업 이력과 증거

### 5.1 보고서 및 카카오 성공 이력

확인된 반도체 보고서: 2026-07-19, 07-20, 07-21, 07-22, 07-24, 07-25, 07-31, 08-02. 07-26부터 07-30 사이에는 일별 실행 흔적은 있으나 07-26·27·28·29·30 보고서가 없다. 08-01도 시작 흔적만 있고 보고서가 없다.

`output/kakao-send.log` 기준 대표 성공 시각:

| 보고서 날짜 | 카카오 성공 시각 | 해석 |
|---|---:|---|
| 2026-07-20 | 20:42 | 수동/늦은 생성 |
| 2026-07-21 | 21:16 | 수동/늦은 생성 |
| 2026-07-22 | 20:42, 20:56 | 같은 보고서 중복 발송 |
| 2026-07-24 | 21:31, 21:32 | 같은 보고서 중복 발송 |
| 2026-07-25 | 14:52, 15:25, 20:03 | 시험/재실행 때마다 동일 보고서 재발송 |
| 2026-07-31 | 19:20 | 08:43 시작 프로세스가 19:20에 완료 |
| 2026-08-02 | 12:48 | 12:41 시작 후 정상 완료 |

따라서 카카오 서버가 임의로 지연 전송했다고 볼 증거는 없다. 현재 로그에서는 API 호출 시각과 사용자가 이상하다고 느낀 도착 시각이 일치하는 방향이다. 가장 강한 설명은 카카오 단계가 늦게 호출됐다는 것이다.

### 5.2 절전/깨우기 시험

2026-07-25 시험에서 확인된 흐름:

- 15:10:05: 전원 버튼으로 Modern Standby 진입
- 15:15:00: 예약된 작업 시각이었지만 자동 wake 및 실행 흔적 없음
- 15:25:20: 마우스 입력으로 사용자가 PC를 깨움
- 15:25:22: `StartWhenAvailable`에 의해 누락 작업 시작
- 15:25:24: 반도체 카카오 발송 완료
- 15:25:28: 전체 시험 완료

결론: `StartWhenAvailable`은 동작했으나 `WakeToRun`/wake timer가 Modern Standby에서 실제 wake를 만들지 못했다. 당시 `powercfg /lastwake`에도 예약 타이머 wake가 없었다.

현재 `powercfg /a` 결과 이 PC는 S3 절전이 아니라 `대기 모드 (S0 저 전원 유휴) 네트워크 연결됨`, 즉 Modern Standby를 사용한다. 최대 절전 모드도 사용 가능하다. 이 차이는 전통적인 S3 wake timer와 동작이 다를 수 있어 핵심 조사 대상이다.

### 5.3 지연 실행의 구체적 증거

- 07-27: 10:00:07에 시작했지만 성공/실패 종료 로그가 없음.
- 07-28: 08:12:12에 시작했지만 종료 로그가 없음.
- 07-29: 18:22:49에 시작했지만 종료 로그가 없음.
- 07-30: 08:01:02에 시작했지만 종료 로그가 없음.
- 07-31: 08:43:57에 Codex attempt 1 시작, **19:20:51**에 exit code 0. 약 10시간 37분의 벽시계 시간이 걸렸으며 곧바로 19:20:55에 카카오 발송.
- 08-01: 08:10:26에 시작했지만 종료 로그가 없음.
- 08-02: 12:41:53 시작, 12:48:27 생성 완료, 12:48:59 카카오 성공. PC와 네트워크가 정상일 때 약 7분 내 완료 가능함을 보여 준다.

07-31의 긴 간격은 Codex가 실제로 10시간 계산했다는 뜻은 아니다. 절전 중 프로세스가 일시 정지됐다가 사용자가 PC를 깨운 뒤 이어졌을 가능성이 높지만, 해당 날짜의 전원 이벤트와 작업 스케줄러 이력을 아직 추출하지 못했으므로 **유력한 가설**로만 취급해야 한다.

### 5.4 초기 오류와 수정 흔적

`output/errors.log`에 다음 오류가 남아 있다.

- 07-23, 07-24: `codex exec exit code: 2`
- 07-25 08:28: Codex CLI 오류
- 07-25 14:09: 환경변수 `Path`/`PATH` 중복 키 오류
- 07-25 14:15: Codex 3회 재시도 실패
- 07-25 14:30: 당시 Codex sandbox가 outbound TCP 443을 차단해 Kakao/GitHub 전송 불가
- 07-26 08:19: Codex 3회 재시도 실패

이후 `Run-DailyReport.ps1`에서 native stderr를 PowerShell terminating error로 오인하지 않도록 `$ErrorActionPreference`를 일시적으로 `Continue`로 바꾸고 `$LASTEXITCODE`를 기준으로 성공을 판정하는 로직이 추가됐다. 실제 07-31과 08-02에는 Codex exit code 0 및 게시/발송 성공이 확인된다.

## 6. 핵심 원인 분석

### A. 전원 버튼 후 예약 시각에 백그라운드 실행되지 않음

확정 사실:

- 전원 버튼은 완전 종료가 아니라 Modern Standby 진입을 발생시켰다.
- 최초 실험에서 예약 wake는 실패했고, 마우스 wake 후 `StartWhenAvailable`로 실행됐다.
- 스크립트에는 `WakeToRun`, AC/DC `RTCWAKE=1`, 07:50 SYSTEM wake guard가 구현돼 있다.
- 현재 세션에서는 작업 조회가 권한 거부되어 이 설정이 실제 등록됐는지 확인하지 못했다.

가능성이 높은 원인:

1. 관리자 등록 스크립트가 실행되지 않았거나 UAC가 취소되어 최신 설정이 실제 작업에 반영되지 않음.
2. Modern Standby/펌웨어/OEM 전원 정책이 예약 타이머 wake를 허용하지 않음.
3. 배터리 절약, 덮개 상태, Windows Update 또는 제조사 전원 관리가 wake timer를 억제함.
4. 반도체 작업이 로그인 사용자 컨텍스트에 묶였고 절전/로그온 상태에서 기대와 다르게 동작함.
5. `RunOnlyIfNetworkAvailable` 조건 때문에 wake 직후 네트워크 프로필이 준비되지 않아 실행이 보류됨.

아직 하지 못한 확인:

- 관리자 PowerShell에서 세 작업의 XML, Principal, Conditions, Settings, LastTaskResult 확인
- `powercfg /waketimers`, `powercfg /requests`, `powercfg /sleepstudy`, `powercfg /systemsleepdiagnostics` 수집
- Event Viewer의 TaskScheduler/Operational 및 Kernel-Power 이벤트를 같은 타임라인으로 대조
- 최신 07:50 SYSTEM wake guard를 등록한 뒤 다시 전원 버튼 시험

### B. 카카오가 원하는 시각이 아닌 때 발송됨

확정 사실:

- 카카오 스크립트에는 발송 예약 기능이 없다.
- 작업 스케줄러 08:00은 **파이프라인 시작 시각**이다.
- 발송은 보고서 생성과 `git push`가 모두 끝난 뒤에만 일어난다.
- 카카오 성공 로그는 실제 늦은 호출 시각을 보여 준다.
- 같은 날짜 보고서가 존재하면 생성은 건너뛰지만 게시·카카오 발송은 다시 수행하므로 수동 재실행과 절전 시험이 중복 발송을 만들었다.

따라서 현재 “이상한 시각” 현상은 다음 조합으로 설명된다.

1. 예약 wake 실패 → 사용자가 PC를 깨운 시점에 `StartWhenAvailable` 실행
2. 실행 중 다시 절전 → Codex 프로세스가 정지했다가 나중에 계속 실행
3. 뉴스 검색·생성 시간 자체의 변동
4. 수동 재시도/시험 작업이 기존 보고서를 다시 발송
5. GitHub push가 지연되면 그 뒤의 카카오 단계도 지연

카카오 API가 요청을 10시간 보관했다가 늦게 전달했다는 증거는 현재 없다.

### C. 스케줄 명세 불일치

- 요구사항: 평일 `0 8 * * 1-5`
- 현재 PowerShell: `New-ScheduledTaskTrigger -Daily -At 8:00AM`
- Wake Guard도 매일 07:50, 대한항공도 매일 08:20
- 실제로 토요일 08-01에도 반도체 실행이 시작됐다.

평일 전용 트리거로 수정해야 한다.

### D. 신뢰성과 관측성 부족

- 중복 실행을 막는 mutex/lock file이 없다.
- 날짜별 `SENT` 상태가 없어 성공한 보고서를 재실행하면 다시 카카오로 보낸다.
- 메시지 4건 중 일부만 성공한 경우 부분 성공 여부를 로그에 남기지 않는다.
- 프로세스 강제 종료·절전 정지 시 `catch`가 실행되지 않아 `errors.log`가 비어 있을 수 있다.
- 실행 단계마다 시작/종료 시각과 소요시간이 충분히 기록되지 않는다.
- `.gitignore`, 스크립트, 문서 대부분이 현재 Git에서 untracked 상태다. 다른 PC나 Claude 환경으로 Git clone만 하면 자동화 코드가 빠질 수 있다.
- `.secrets`는 반드시 Git에 넣지 않아야 하지만, 새 환경에서 카카오 재인증 절차가 필요하다.

## 7. Claude가 가장 먼저 수행할 작업

### 1순위 — 현재 상태를 관리자 권한으로 증거 수집

관리자 PowerShell에서 아래를 실행하고 결과를 `output/diagnostics-YYYY-MM-DD.txt`로 저장한다. 비밀값은 출력하지 않는다.

```powershell
Get-ScheduledTask -TaskName 'Daily Report Wake Guard','Semiconductor Daily Report','Korean Air Daily Scrap' |
  Export-ScheduledTask
Get-ScheduledTaskInfo -TaskName 'Daily Report Wake Guard'
Get-ScheduledTaskInfo -TaskName 'Semiconductor Daily Report'
Get-ScheduledTaskInfo -TaskName 'Korean Air Daily Scrap'
powercfg /a
powercfg /waketimers
powercfg /lastwake
powercfg /requests
powercfg /sleepstudy /output "$PWD\output\sleepstudy.html"
```

`Microsoft-Windows-TaskScheduler/Operational` 로그가 꺼져 있으면 활성화한 뒤, 한 번의 통제된 시험에서 Task ID 100/101/102/107/129/200/201과 Kernel-Power 506/507을 수집한다.

### 2순위 — 작은 wake-only 검증부터 다시 수행

보고서 생성이나 카카오를 섞지 말고 다음처럼 단계화한다.

1. 현재 시각 +10분에 SYSTEM `WakeToRun` 작업 등록.
2. 작업은 단지 타임스탬프 파일 한 줄 기록만 수행.
3. `powercfg /waketimers`에 타이머가 보이는지 확인.
4. AC 연결 상태에서 전원 버튼으로 Modern Standby 진입.
5. 사람 입력 없이 파일 생성 및 Kernel-Power wake reason 확인.
6. AC 성공 후 배터리에서 반복.

이 시험도 실패하면 Windows 스크립트 수정만 반복하지 말고 BIOS/OEM/Modern Standby 제약으로 판단하고 상시 실행 환경 이전을 우선 검토한다.

### 3순위 — 스케줄 및 Principal 명시화

- 세 작업을 평일 전용 trigger로 변경.
- 반도체 작업 Principal을 명시하고, 사용자 로그온 없이도 Codex 자격증명과 파일 접근이 가능한지 확인.
- `RunOnlyIfNetworkAvailable`가 wake 직후 작업을 무기한 늦추는지 시험하고, 필요하면 작업은 즉시 시작하되 러너 내부에서 제한 시간 네트워크 재시도를 수행.
- 관리자 등록 후 등록된 XML을 다시 읽어 설정이 실제 반영됐음을 자동 검증.

주의: Codex CLI 로그인 정보가 사용자 프로필에 저장돼 있다면 SYSTEM 계정으로 메인 보고서 생성 작업을 옮기는 순간 인증이 깨질 수 있다. Wake Guard만 SYSTEM으로 두고 메인 작업은 전용 사용자 계정의 `Password`/S4U 방식 또는 외부 실행 환경을 검토해야 한다.

### 4순위 — 카카오 중복 방지와 발송 시각 정책 결정

- `output/delivery-state.json` 같은 상태 파일에 날짜, 보고서 hash, 각 메시지 1–4의 성공 시각을 기록.
- 동일 날짜·동일 hash가 전부 성공했으면 기본 재실행 시 발송 생략.
- 강제 재발송은 별도 `-ForceResend` 옵션으로만 허용.
- 각 API 호출 전후를 기록해 부분 성공 시 실패한 part부터 재개.
- 원하는 정책을 둘 중 하나로 확정:
  - **최신성 우선:** 08:00 생성 시작, 완료 시 발송. 도착 시각 변동을 정상으로 안내.
  - **정시성 우선:** 더 이른 시각/전날 생성하고 08:00에는 이미 준비된 요약만 발송.

### 5순위 — 실행 안정성과 로그 개선

- 전역 mutex 또는 atomic lock으로 반도체 작업 중복 실행 차단.
- 생성, 게시, 카카오를 재개 가능한 독립 단계로 분리.
- 각 단계의 시작/종료/elapsed time, PID, task invocation ID 기록.
- 종료되지 않은 이전 실행을 다음 실행이 감지하고 상태를 `abandoned`로 남김.
- Codex 실행에 합리적인 벽시계 timeout을 두되 절전 시간을 오판하지 않도록 전원 이벤트도 함께 기록.
- GitHub push 실패가 카카오까지 막아야 하는지 정책 결정. 현재는 push 성공 전에는 카카오를 보내지 않는다.

### 6순위 — 저장소 정리

현재 `git status --short` 기준 자동화 스크립트, `AGENTS.md`, 설정 문서, 대한항공 하위 프로젝트 등이 대량으로 untracked다. 필요한 소스와 문서는 커밋하고 다음은 제외해야 한다.

- `.secrets/`
- 카카오 access/refresh token 및 API secret
- 대용량 `output/codex-*.err.log`, 일회성 시험 로그
- 필요하면 진단용 로그는 민감정보 제거 후 별도 보관

Claude에게 Git만 넘길 경우, 이 정리와 커밋 전에는 현재 작업의 상당 부분이 전달되지 않는다.

## 8. 권장 아키텍처

### 단기: 현재 Windows PC 유지

- 07:30 또는 07:40에 생성 시작
- wake-only 시험 통과를 전제
- 생성과 발송 작업 분리
- 08:00 발송 작업은 준비된 보고서가 있을 때만 전송
- 없으면 08:05, 08:15처럼 제한된 재시도 후 실패 알림
- idempotency와 mutex 필수

### 장기: 항상 켜진 실행 환경으로 이전

Modern Standby wake가 다시 실패하면 GitHub Actions, 클라우드 VM, NAS 등 상시 실행 환경이 더 적합하다. 다만 다음을 별도로 해결해야 한다.

- Codex CLI를 비대화형 서버에서 인증·실행할 수 있는지
- Kakao refresh token과 client secret의 안전한 secret 저장
- Kakao API outbound 접속 허용
- GitHub Pages push 권한
- Asia/Seoul 평일 스케줄과 실패 알림

PC 전원 상태에 의존하지 않는 것이 정시성 문제의 가장 근본적인 해결책이다.

## 9. 완료 판정 기준

다음 조건을 모두 증거로 남겨야 해결 완료로 볼 수 있다.

1. AC 연결 Modern Standby에서 사람 입력 없이 07:50 wake 성공을 3회 연속 확인.
2. 가능하면 배터리에서도 3회 연속 확인하거나, 지원하지 않으면 명시적으로 제한 기록.
3. 평일에만 작업이 실행되고 주말 `NextRunTime`이 월요일로 잡힘.
4. 반도체 생성이 오래 걸려도 중복 프로세스가 생기지 않음.
5. 같은 보고서 재실행 시 카카오 중복 발송이 없음.
6. 네 메시지 중 실패가 있으면 실패 part만 재시도 가능.
7. 목표가 정시 발송이면 08:00 ±1분을 5영업일 연속 달성.
8. 실패 시 작업 스케줄러 이력, 전원 이벤트, 러너 로그만으로 원인을 재구성 가능.

## 10. 보안 및 인수인계 주의사항

- `.secrets/kakao-token.json` 내용은 문서, Git, Claude 대화에 붙여 넣지 않는다.
- `KAKAO_REST_API_KEY`, `KAKAO_CLIENT_SECRET` 값도 출력하지 않는다.
- 새 PC/사용자 계정에서는 `scripts/Initialize-Kakao.ps1`로 다시 인증해야 할 수 있다.
- 현재 카카오 기능은 일반 친구 발송이 아니라 Kakao API의 `talk/memo/default/send`, 즉 인증한 본인의 **나에게 보내기**다.
- 완전 종료된 Windows PC는 작업 스케줄러가 깨울 수 없다. BIOS 예약 전원 켜기 또는 외부 서버가 필요하다.

## 11. Claude에게 전달할 첫 요청 예시

> `CLAUDE_HANDOFF.md`, `AGENTS.md`, 관련 PowerShell과 output 로그를 먼저 읽고, 코드를 바로 고치기 전에 관리자 권한 진단 결과로 현재 등록 작업과 Modern Standby wake 실패를 재현해 주세요. 확인된 사실과 가설을 분리하고, 먼저 wake-only 시험을 통과시킨 다음 평일 스케줄, 중복 실행 방지, 카카오 idempotency를 구현해 주세요. 정시성 우선과 최신성 우선 중 어느 정책인지 사용자에게 확인하기 전에는 발송 시각 구조를 임의로 결정하지 마세요. 비밀값은 출력하거나 커밋하지 마세요.

---

이 문서는 현재 저장소의 스크립트, Git 이력, `output/run-*.log`, `output/kakao-send.log`, `output/errors.log`, 2026-07-25 절전 시험 기록, 현재 `powercfg /a` 결과를 근거로 작성했다. 작업 스케줄러의 최종 등록 상태와 상세 전원 이벤트는 권한 부족으로 확인하지 못했으므로 Claude가 관리자 권한으로 가장 먼저 보완해야 한다.
