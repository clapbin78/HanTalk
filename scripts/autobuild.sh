#!/bin/bash
# ─────────────────────────────────────────────────────────────
# 한톡 자동 빌드 도우미 v3 (Flutter)
#
# .build-request 파일 내용(첫 줄)에 따라 동작:
#   test    → hanchat 패키지: pub get + analyze + 전체 테스트 (기본)
#   analyze → 정적 분석만 (빠름)
#   app     → 한톡 앱 빌드 (app/ 폴더 — 생성 후 사용 가능)
#
# 매 실행 전 아키텍처 규칙 검사(scripts/archcheck.sh)를 먼저 돌린다.
# 결과: scripts/build-status.txt, 로그: scripts/build-latest.log
#
# 실행:  bash ~/HanTalk/scripts/autobuild.sh   (종료: Ctrl+C)
# ─────────────────────────────────────────────────────────────
set -u
cd "$(dirname "$0")/.." || exit 1

echo "👀 빌드 요청 대기 중... v3-flutter (test/analyze/app · Ctrl+C로 종료)"
echo "IDLE" > scripts/build-status.txt

while true; do
  if [ -f .build-request ]; then
    MODE=$(head -1 .build-request | tr -d '[:space:]')
    [ -z "$MODE" ] && MODE=test
    rm -f .build-request
    echo "🔨 $(date '+%H:%M:%S') 모드: $MODE"
    echo "RUNNING $MODE" > scripts/build-status.txt

    # 0) 아키텍처 규칙 검사
    if ! bash scripts/archcheck.sh > scripts/build-latest.log 2>&1; then
      echo "ARCH_FAILED $(date '+%H:%M:%S')" > scripts/build-status.txt
      echo "🚨 아키텍처 규칙 위반 — 빌드 중단"
      continue
    fi

    RESULT=1
    case "$MODE" in
      analyze)
        ( cd hanchat && flutter pub get && flutter analyze ) \
          >> scripts/build-latest.log 2>&1
        RESULT=$? ;;
      app)
        if [ ! -d app ]; then
          echo "NEEDS_APP_SCAFFOLD" > scripts/build-status.txt
          echo "⚠️  app/ 폴더가 아직 없어요"
          continue
        fi
        ( cd app && flutter pub get && flutter build ios --no-codesign --simulator ) \
          >> scripts/build-latest.log 2>&1
        RESULT=$? ;;
      *)
        ( cd hanchat && flutter pub get && flutter analyze && flutter test ) \
          >> scripts/build-latest.log 2>&1
        RESULT=$?
        # app도 pub get으로 새 패키지 반영 (hanchat 의존성 추가 시 app 갱신 필수)
        if [ $RESULT -eq 0 ] && [ -d app ]; then
          ( cd app && flutter pub get ) >> scripts/build-latest.log 2>&1 || true
        fi
        # Firebase 어댑터 패키지도 정적 분석 (테스트는 에뮬레이터 필요라 제외)
        if [ $RESULT -eq 0 ] && [ -d hanchat_firebase ]; then
          ( cd hanchat_firebase && flutter pub get && flutter analyze ) \
            >> scripts/build-latest.log 2>&1
          RESULT=$?
        fi ;;
    esac

    if [ $RESULT -eq 0 ]; then
      echo "SUCCEEDED $MODE $(date '+%H:%M:%S')" > scripts/build-status.txt
      echo "✅ $MODE 성공!"
    else
      echo "FAILED $MODE $(date '+%H:%M:%S')" > scripts/build-status.txt
      grep -E "error|Error|FAILED|failed" scripts/build-latest.log \
        | sort -u | head -30 > scripts/build-errors.txt || true
      echo "❌ $MODE 실패 — Claude가 로그를 읽고 수정할 거예요"
    fi
  fi
  sleep 2
done
