# QA 로테이션

쉬는 시간 5~10분에 앱 하나씩 QA한다. 40여 개 앱이 2주에 한 번쯤 모두 점검되도록 오늘 할 앱을 골라 준다.

- 홈 화면: "QA 시작" 한 번이면 체크리스트가 열린다
- 위젯, 알림을 누르면 그 앱의 세션으로 바로 들어간다
- 실패한 항목은 이슈가 되고, 다음 QA 때 맨 위에서 다시 확인한다

## 빌드

```sh
xcodegen generate
xcodebuild -project QARotation.xcodeproj -scheme QARotation \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

기기에 설치하려면 `project.yml`의 `DEVELOPMENT_TEAM`을 채우고 App Group `group.com.leeo.QARotation`을 등록한다.

결정 사항은 [DECISIONS.md](DECISIONS.md)에 있다.
