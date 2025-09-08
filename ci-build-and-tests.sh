set -euo pipefail

echo "===================pods===================="
# 不清理 Pods，配合 CI 缓存提升速度
pod install || pod install --repo-update

echo "===================tests===================="
sh unit-tests.sh

echo "=================build App=================="
# 允许通过环境变量传入 DerivedData 目录，配合 CI 缓存
export DERIVED_DATA_PATH=${DERIVED_DATA_PATH:-"$PWD/.derived_data"}
export OBJROOT="$DERIVED_DATA_PATH/Build/Intermediates.noindex"
export SYMROOT="$DERIVED_DATA_PATH/Build/Products"
sh build.sh
