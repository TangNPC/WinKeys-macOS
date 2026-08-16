#!/bin/zsh
set -euo pipefail

script_dir=${0:A:h}
project_dir=${script_dir:h}
derived_data="${TMPDIR:-/tmp}/WinKeysReleaseDerivedData"
product_dir="$project_dir/release"
product="$product_dir/WinKeys.app"
destination="/Applications/WinKeys.app"

mkdir -p "$product_dir"

xcodebuild \
  -project "$project_dir/WinKeys.xcodeproj" \
  -scheme WinKeys \
  -configuration Release \
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

ditto "$product" "$destination"

codesign --verify --deep --strict --verbose=2 "$destination"
codesign -d -r- "$destination" 2>&1
