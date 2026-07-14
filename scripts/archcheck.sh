#!/bin/bash
# ─────────────────────────────────────────────────────────────
# Clean Architecture + MVVM 의존성 규칙 자동 검사
# 규칙은 ARCHITECTURE.md 참고. 위반 시 exit 1.
# ─────────────────────────────────────────────────────────────
cd "$(dirname "$0")/../HanChatKit/Sources" || exit 1
fail=0

check() { # 이름 / 디렉터리 / 금지 패턴 / 설명
  local hits
  hits=$(grep -rnE "$3" "$2" --include='*.swift' 2>/dev/null)
  if [ -n "$hits" ]; then
    echo "❌ [$1] $4"
    echo "$hits" | head -5
    fail=1
  else
    echo "✅ [$1] $4"
  fi
}

check "규칙1" HanChatCore \
  '^import (SwiftUI|UIKit|SwiftData|Firebase|Contacts|UserNotifications|WebKit|CryptoKit)' \
  "Core는 순수 Swift — 프레임워크 import 금지"

check "규칙2" HanChatCore \
  'HanChatData|HanChatUI|HanChatFirebase' \
  "Core는 바깥 레이어의 존재를 모른다"

check "규칙3" HanChatData \
  '^import (SwiftUI|UIKit|WebKit)|^import Firebase' \
  "Data는 UI·특정 백엔드를 모른다"

check "규칙4" HanChatUI \
  '^import Firebase' \
  "UI는 특정 백엔드를 모른다 (프로토콜만 안다)"

check "규칙5" HanChatUI \
  '\.(user|friend|room|message)Repository' \
  "View/ViewModel은 UseCase만 호출 — Repository 직접 접근 금지"

echo ""
if [ $fail -eq 0 ]; then
  echo "🏛  아키텍처 검사 통과"
else
  echo "🚨 아키텍처 규칙 위반 — 위 항목을 수정하세요"
fi
exit $fail
