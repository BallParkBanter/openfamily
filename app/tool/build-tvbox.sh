#!/usr/bin/env bash
# build-tvbox.sh — the BrayTV box release: x86_64 only, Impeller OFF (its
# Vulkan swapchain fails: ErrorSurfaceLostKHR), the same build number scheme
# as the tablet build. Run from app/ inside the Flutter container exactly
# like the tablet build; the APK lands in build/app/outputs/flutter-apk/.
#   flutter build apk --release --target-platform android-x64 -Pimpeller=false --build-number=N
set -euo pipefail
cd "$(dirname "$0")/.."
exec flutter build apk --release --target-platform android-x64 -Pimpeller=false --build-number="${1:-$(( $(date +%s) / 60 ))}"
