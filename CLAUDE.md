# Marshroom

GitHub Issue를 SSOT로 삼는 macOS 개발자 생산성 도구.

## 프로젝트 구조
- `Marshroom/` — Xcode 앱 프로젝트 (SwiftUI + AppKit, macOS 14.0+)
- `Skills/` — Claude Code 커스텀 슬래시 커맨드 설치 자료
- `.claude/commands/` — Claude Code 스킬 (start-issue, create-pr, validate-pr)

## 기술 스택
- SwiftUI + AppKit (MenuBarExtra for system tray)
- `@Observable` 패턴 (not ObservableObject)
- `actor` 기반 GitHub API 클라이언트 + async/await
- Keychain: PAT 저장, UserDefaults: 설정, `~/.config/marshroom/state.json`: Claude Code 브릿지

## 빌드 & 실행
```bash
xcodebuild -project Marshroom/Marshroom.xcodeproj -scheme Marshroom -configuration Debug build
```

## 핵심 규칙
- GitHub Issue가 SSOT — 앱은 라벨(`todo-today`)로 상태를 관리
- Cart 기준: `todo-today` 라벨 + 현재 사용자에게 assign (멀티유저 안전)
- 단일 active issue 없음 — 모든 cart item 동등 (병렬 작업 가능)
- state.json v2: `activeIssue` 제거, `CartEntry`에 `repoCloneURL`/`repoSSHURL` 포함
- state.json은 원자적 쓰기(`Data.write(options: .atomic)`)로 Claude Code 동시 읽기와 충돌 방지
- `GitHubIssue.branchName`: 제목에 Bug/Fix/HotFix 포함 시 `HotFix/#N`, 아니면 `Feature/#N`
- Claude Code 스킬: `state.json`의 cart에서 현재 repo 매칭 + branch name 매칭으로 issue 식별
