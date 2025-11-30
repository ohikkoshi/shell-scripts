#!/usr/bin/env bash
# =============================================================================
# download_increment.sh
# 指定したURLの番号部分をインクリメントしながらファイルをダウンロードする
#
# 使い方:
#   ./download_increment.sh [オプション]
#
# 例:
#   ./download_increment.sh -u "https://example.com/file_{NUM}.jpg" -s 1 -e 100
#   ./download_increment.sh -u "https://example.com/img_{NUM}.png" -s 001 -e 050 -z 3
# =============================================================================

set -euo pipefail

# -----------------------------------------------
# デフォルト設定
# -----------------------------------------------
BASE_URL=""              # URLテンプレート ({NUM} が置換される)
START=1                  # 開始番号
END=10                   # 終了番号
ZERO_PAD=0               # ゼロ埋め桁数 (0=無効)
OUTPUT_DIR="./downloads" # 保存先ディレクトリ
DELAY=0.5                # ダウンロード間隔 (秒)
RETRY=3                  # リトライ回数
SKIP_EXISTING=true       # 既存ファイルをスキップ
STEP=1                   # インクリメント幅
DRY_RUN=false            # ドライラン (実際にはDLしない)
LOG_FILE=""              # ログファイルパス (空=ログなし)

# -----------------------------------------------
# カラー出力
# -----------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RESET='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${RESET}  $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
log_error() { echo -e "${RED}[ERROR]${RESET} $*" >&2; }
log_debug() { echo -e "${CYAN}[DRY]${RESET}   $*"; }

# -----------------------------------------------
# ヘルプ表示
# -----------------------------------------------
usage() {
	cat <<EOF
使い方: $(basename "$0") [オプション]

必須オプション:
  -u <URL>      URLテンプレート。番号の位置に {NUM} を記述する
                例: "https://example.com/img_{NUM}.jpg"

番号指定:
  -s <数値>     開始番号 (デフォルト: ${START})
  -e <数値>     終了番号 (デフォルト: ${END})
  -t <数値>     ステップ幅 (デフォルト: ${STEP})
  -z <桁数>     ゼロ埋め桁数 例: -z 3 → 001,002,...
                ※ -s に "001" のようにゼロ埋めした値を渡しても自動検出

保存オプション:
  -o <ディレクトリ>  保存先 (デフォルト: ${OUTPUT_DIR})
  -f            既存ファイルがあっても上書きダウンロード

通信オプション:
  -d <秒>       ダウンロード間隔 (デフォルト: ${DELAY}秒)
  -r <回数>     リトライ回数 (デフォルト: ${RETRY})

その他:
  -l <ファイル> ログをファイルにも出力
  -n            ドライラン (URLを表示するだけでDLしない)
  -h            このヘルプを表示

使用例:
  # 連番JPEGを1〜100ダウンロード
  $(basename "$0") -u "https://example.com/photo_{NUM}.jpg" -s 1 -e 100

  # ゼロ埋め3桁で001〜050をダウンロード
  $(basename "$0") -u "https://example.com/img_{NUM}.png" -s 1 -e 50 -z 3

  # 偶数番号のみ (ステップ2)
  $(basename "$0") -u "https://example.com/data_{NUM}.csv" -s 2 -e 20 -t 2

  # ドライランで対象URLを確認
  $(basename "$0") -u "https://example.com/file_{NUM}.pdf" -s 10 -e 15 -n
EOF
	exit 0
}

# -----------------------------------------------
# オプション解析
# -----------------------------------------------
while getopts "u:s:e:t:z:o:d:r:l:nfh" opt; do
	case $opt in
	u) BASE_URL="$OPTARG" ;;
	s) START="$OPTARG" ;;
	e) END="$OPTARG" ;;
	t) STEP="$OPTARG" ;;
	z) ZERO_PAD="$OPTARG" ;;
	o) OUTPUT_DIR="$OPTARG" ;;
	d) DELAY="$OPTARG" ;;
	r) RETRY="$OPTARG" ;;
	l) LOG_FILE="$OPTARG" ;;
	n) DRY_RUN=true ;;
	f) SKIP_EXISTING=false ;;
	h) usage ;;
	*) usage ;;
	esac
done

# -----------------------------------------------
# ログファイル設定
# -----------------------------------------------
if [[ -n "$LOG_FILE" ]]; then
	exec > >(tee -a "$LOG_FILE") 2>&1
fi

# -----------------------------------------------
# 入力チェック
# -----------------------------------------------
if [[ -z "$BASE_URL" ]]; then
	log_error "URLテンプレートが指定されていません。-u オプションを使用してください。"
	log_error "例: -u \"https://example.com/file_{NUM}.jpg\""
	exit 1
fi

if [[ "$BASE_URL" != *"{NUM}"* ]]; then
	log_error "URLテンプレートに {NUM} が含まれていません: $BASE_URL"
	exit 1
fi

# START の文字列にゼロが含まれる場合、自動でゼロ埋め桁数を検出
if [[ "$START" =~ ^0[0-9]+ ]] && [[ "$ZERO_PAD" -eq 0 ]]; then
	ZERO_PAD=${#START}
	log_warn "開始番号からゼロ埋め桁数を自動検出: ${ZERO_PAD}桁"
fi

# 数値変換
START_NUM=$(echo "$START" | sed 's/^0*//' | grep -o '[0-9]*' || echo "0")
END_NUM=$(echo "$END" | sed 's/^0*//' | grep -o '[0-9]*' || echo "0")
[[ -z "$START_NUM" ]] && START_NUM=0
[[ -z "$END_NUM" ]] && END_NUM=0

# -----------------------------------------------
# 保存ディレクトリ作成
# -----------------------------------------------
if [[ "$DRY_RUN" == false ]]; then
	mkdir -p "$OUTPUT_DIR"
	log_info "保存先: $(realpath "$OUTPUT_DIR")"
fi

# -----------------------------------------------
# curl の存在確認
# -----------------------------------------------
if ! command -v curl &>/dev/null; then
	log_error "curl がインストールされていません。"
	exit 1
fi

# -----------------------------------------------
# ダウンロード統計
# -----------------------------------------------
COUNT_SUCCESS=0
COUNT_SKIP=0
COUNT_FAIL=0
FAILED_URLS=()

TOTAL=$(((END_NUM - START_NUM) / STEP + 1))
log_info "ダウンロード開始: ${START_NUM} 〜 ${END_NUM} (ステップ: ${STEP}, 合計: ${TOTAL}件)"
echo "-----------------------------------------------------"

# -----------------------------------------------
# メインループ
# -----------------------------------------------
INDEX=0
for ((i = START_NUM; i <= END_NUM; i += STEP)); do
	INDEX=$((INDEX + 1))

	# ゼロ埋め処理
	if [[ "$ZERO_PAD" -gt 0 ]]; then
		NUM=$(printf "%0${ZERO_PAD}d" "$i")
	else
		NUM="$i"
	fi

	# URL 生成
	URL="${BASE_URL//\{NUM\}/$NUM}"

	# ファイル名をURLから取得
	FILENAME=$(basename "$URL" | cut -d'?' -f1)
	SAVE_PATH="${OUTPUT_DIR}/${FILENAME}"

	PROGRESS="[${INDEX}/${TOTAL}]"

	# ドライランモード
	if [[ "$DRY_RUN" == true ]]; then
		log_debug "${PROGRESS} → $URL"
		continue
	fi

	# 既存ファイルスキップ
	if [[ "$SKIP_EXISTING" == true && -f "$SAVE_PATH" ]]; then
		log_warn "${PROGRESS} スキップ (既存): $FILENAME"
		COUNT_SKIP=$((COUNT_SKIP + 1))
		continue
	fi

	# ダウンロード実行
	echo -ne "${CYAN}[DL]${RESET}   ${PROGRESS} $URL ... "

	HTTP_CODE=$(curl \
		--silent \
		--show-error \
		--location \
		--retry "$RETRY" \
		--retry-delay 2 \
		--output "$SAVE_PATH" \
		--write-out "%{http_code}" \
		--user-agent "Mozilla/5.0 (compatible; download_increment.sh)" \
		"$URL" 2>&1) || true

	if [[ "$HTTP_CODE" == "200" ]]; then
		FILE_SIZE=$(du -sh "$SAVE_PATH" 2>/dev/null | cut -f1)
		echo -e "${GREEN}OK${RESET} (${HTTP_CODE}, ${FILE_SIZE})"
		COUNT_SUCCESS=$((COUNT_SUCCESS + 1))
	else
		echo -e "${RED}FAIL${RESET} (HTTP ${HTTP_CODE})"
		log_error "  失敗: $URL"
		FAILED_URLS+=("$URL")
		COUNT_FAIL=$((COUNT_FAIL + 1))
		# 失敗したファイルを削除
		rm -f "$SAVE_PATH"
	fi

	# インターバル (最後の1件はスキップ)
	if [[ "$i" -lt "$END_NUM" ]] && [[ "$(echo "$DELAY > 0" | bc -l)" == "1" ]]; then
		sleep "$DELAY"
	fi

done

# -----------------------------------------------
# サマリー表示
# -----------------------------------------------
echo "====================================================="
log_info "完了"
echo -e "  ${GREEN}成功:${RESET} ${COUNT_SUCCESS}件"
echo -e "  ${YELLOW}スキップ:${RESET} ${COUNT_SKIP}件"
echo -e "  ${RED}失敗:${RESET} ${COUNT_FAIL}件"

if [[ ${#FAILED_URLS[@]} -gt 0 ]]; then
	echo ""
	log_warn "失敗したURL一覧:"
	for url in "${FAILED_URLS[@]}"; do
		echo "  - $url"
	done
fi

if [[ "$DRY_RUN" == false && "$COUNT_SUCCESS" -gt 0 ]]; then
	echo ""
	log_info "保存先: $(realpath "$OUTPUT_DIR")"
fi
