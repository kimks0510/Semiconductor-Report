# 카카오톡 나에게 보내기 설정

비밀키는 저장소 파일에 적지 않고 Windows 사용자 환경변수로 관리한다.

1. Kakao Developers에서 앱을 만들고 카카오 로그인을 활성화한다.
2. Redirect URI에 `http://localhost:8766/oauth`를 등록한다.
3. 동의항목에서 `talk_message`(카카오톡 메시지 전송)를 활성화한다.
4. PowerShell에서 다음 명령을 실행한다. 값은 본인의 키로 바꾼다.

```powershell
[Environment]::SetEnvironmentVariable('KAKAO_REST_API_KEY', '본인의_REST_API_KEY', 'User')
[Environment]::SetEnvironmentVariable('KAKAO_CLIENT_SECRET', '본인의_CLIENT_SECRET', 'User')
```

5. PowerShell을 새로 연 뒤 최초 인증을 실행한다.

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\Initialize-Kakao.ps1
```

6. 시험 발송을 실행한다.

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\Send-KakaoBriefing.ps1 -BriefingPath .\output\2026-07-19-briefing.md
```

7. 시험 발송 성공 후 평일 오전 8시 예약 작업을 등록한다.

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\Register-DailyTask.ps1
```

토큰은 프로젝트의 `.secrets/kakao-token.json`에 저장되며 `.gitignore`에 의해 Git 저장소에는 포함되지 않는다. 실패 로그는 `output/errors.log`, 성공 발송 기록은 `output/kakao-send.log`에 남는다.
