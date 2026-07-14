#!/bin/bash
# ─────────────────────────────────────────────────────────────
# Clean Architecture + MVVM 의존성 규칙 자동 검사 (Flutter/Dart)
# 규칙은 ARCHITECTURE.md 참고. 위반 시 exit 1.
# ─────────────────────────────────────────────────────────────
cd "$(dirname "$0")/../hanchat/lib" || exit 1
fail=0

check() { # 이름 / 디렉터리 / 금지 패턴 / 설명
  local hits
  hits=$(grep -rnE "$3" "$2" --include='*.dart' 2>/dev/null)
  if [ -n "$hits" ]; then
    echo "❌ [$1] $4"
    echo "$hits" | head -5
    fail=1
  else
    echo "✅ [$1] $4"
  fi
}

check "규칙1" src/core \
  "import 'package:(flutter|firebase|sqflite|shared_preferences|cloud_firestore)" \
  "core는 순수 Dart — 프레임워크/DB import 금지"

check "규칙2" src/core \
  "import '.*/data/|import '.*/ui/" \
  "core는 바깥 레이어의 존재를 모른다"

check "규칙3" src/data \
  "import 'package:flutter/" \
  "data는 UI(Flutter 위젯)를 모른다"

if [ -d src/ui ]; then
  check "규칙4" src/ui \
    "import 'package:(firebase|cloud_firestore|sqflite)" \
    "ui는 특정 백엔드·DB를 모른다"

  check "규칙5" src/ui \
    "Repository\(" \
    "View/ViewModel은 UseCase만 호출 — Repository 직접 생성/접근 금지"
fi

echo ""
if [ $fail -eq 0 ]; then
  echo "🏛  아키텍처 검사 통과"
else
  echo "🚨 아키텍처 규칙 위반 — 위 항목을 수정하세요"
fi
exit $fail
