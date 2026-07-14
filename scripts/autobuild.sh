#!/bin/bash
# ─────────────────────────────────────────────────────────────
# HanChatKit 자동 빌드 도우미 v2
#
# .build-request 파일 내용(첫 줄)에 따라 동작:
#   build → SDK 패키지 빌드 (기본)
#   test  → 유닛 테스트 실행
#   demo  → 데모 앱 생성(xcodegen) + 빌드
#
# 매 실행 전 아키텍처 규칙 검사(scripts/archcheck.sh)를 먼저 돌린다.
# 결과: scripts/build-status.txt, scripts/build-latest.log
#
# 실행:  bash ~/HanTalk/scripts/autobuild.sh   (종료: Ctrl+C)
# ─────────────────────────────────────────────────────────────
set -u
cd "$(dirname "$0")/.." || exit 1
SIM_DEST='platform=iOS Simulator,name=iPhone 17'

echo "👀 빌드 요청 대기 중... (build/test/demo · Ctrl+C로 종료)"
echo "IDLE" > scripts/build-status.txt

while true; do
  if [ -f .build-request ]; then
    MODE=$(head -1 .build-request | tr -d '[:space:]')
    [ -z "$MODE" ] && MODE=build
    rm -f .build-request
    echo "🔨 $(date '+%H:%M:%S') 모드: $MODE"
    echo "RUNNING $MODE" > scripts/build-status.txt

    # 0) 아키텍처 규칙 검사
    if ! bash scripts/archcheck.sh > scripts/build-latest.log 2>&1; then
      echo "ARCH_FAILED $(date '+%H:%M:%S')" > scripts/build-status.txt
      echo "🚨 아키텍처 규칙 위반 — 빌드 중단"
      continue
    fi

    case "$MODE" in
      test)
        ( cd HanChatKit && xcodebuild -scheme HanChatKit-Package \
            -destination "$SIM_DEST" test ) >> scripts/build-latest.log 2>&1
        PASS_PATTERN="TEST SUCCEEDED" ;;
      demo)
        if ! command -v xcodegen > /dev/null; then
          echo "NEEDS_XCODEGEN" > scripts/build-status.txt
          echo "⚠️  xcodegen이 없어요: brew install xcodegen"
          continue
        fi
        ( cd DemoApp && xcodegen && \
          xcodebuild -project HanTalkDemo.xcodeproj -scheme HanTalkDemo \
            -destination "$SIM_DEST" build ) >> scripts/build-latest.log 2>&1
        PASS_PATTERN="BUILD SUCCEEDED" ;;
      *)
        ( cd HanChatKit && xcodebuild -scheme HanChatKit-Package \
            -destination "generic/platform=iOS Simulator" build ) \
            >> scripts/build-latest.log 2>&1
        PASS_PATTERN="BUILD SUCCEEDED" ;;
    esac

    if grep -q "$PASS_PATTERN" scripts/build-latest.log; then
      echo "SUCCEEDED $MODE $(date '+%H:%M:%S')" > scripts/build-status.txt
      echo "✅ $MODE 성공!"
    else
      echo "FAILED $MODE $(date '+%H:%M:%S')" > scripts/build-status.txt
      grep -E "error:|Test Case.*failed|failed \(" scripts/build-latest.log \
        | sort -u > scripts/build-errors.txt || true
      echo "❌ $MODE 실패 — Claude가 로그를 읽고 수정할 거예요"
    fi
  fi
  sleep 2
done
