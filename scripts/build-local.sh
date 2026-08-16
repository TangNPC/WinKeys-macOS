#!/bin/zsh
set -euo pipefail

script_dir=${0:A:h}
project_dir=${script_dir:h}
derived_data="${TMPDIR:-/tmp}/WinKeysLocalDerivedData"
product_dir="$project_dir/build"
product="$product_dir/WinKeys.app"

mkdir -p "$product_dir"

xcodebuild \
  -project "$project_dir/WinKeys.xcodeproj" \
  -scheme WinKeys \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath "$derived_data" \
  CONFIGURATION_BUILD_DIR="$product_dir" \
  build

codesign \
  --force \
  --deep \
  --sign - \
  --identifier com.oxygen.WinKeys \
  --requirements '=designated => identifier "com.oxygen.WinKeys"' \
  "$product"

codesign --verify --deep --strict --verbose=2 "$product"
codesign -d -r- "$product" 2>&1
