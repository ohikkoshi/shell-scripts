#!/bin/bash
# .zsh_history の重複コマンドを列挙し、最新の1件だけを残して削除する
#
# 使い方:
#   ./dedup_zsh_history.sh            # ドライラン(列挙のみ、変更なし)
#   ./dedup_zsh_history.sh --apply    # 実際に削除(バックアップ自動作成)
#   ./dedup_zsh_history.sh --apply -f /path/to/history

export LC_ALL=C

APPLY=0
HIST="${HISTFILE:-$HOME/.zsh_history}"

while (($# > 0)); do
	case "$1" in
	--apply) APPLY=1 ;;
	-f)
		shift
		HIST="$1"
		;;
	*)
		echo "不明な引数: $1" >&2
		exit 1
		;;
	esac
	shift
done

[[ -f "$HIST" ]] || {
	echo "履歴ファイルが見つかりません: $HIST" >&2
	exit 1
}

TMP_OUT="$(mktemp)"
TMP_DUP="$(mktemp)"
trap 'rm -f "$TMP_OUT" "$TMP_DUP"' EXIT

# 複数行コマンド(行末が \ で続くもの)を1レコードにまとめて処理する。
# 各レコードの「コマンド本体」(タイムスタンプ除去後)をキーに、
# ファイル末尾(=最新)側のものを残す。
awk '
  function flush_record() {
    if (rec != "") { n++; recs[n] = rec; rec = "" }
  }
  {
    line = $0
    if (rec == "") {
      rec = line
    } else {
      rec = rec "\n" line
    }
    # 行末がバックスラッシュなら次の行も同じレコード
    if (line !~ /\\$/) flush_record()
  }
  END {
    flush_record()
    # 末尾(最新)から走査し、初出のキーだけ残す
    for (i = n; i >= 1; i--) {
      r = recs[i]
      key = r
      sub(/^: [0-9]+:[0-9]+;/, "", key)
      if (key in seen) {
        dup_count[key]++
        removed++
        print "D\t" dup_count[key] "\t" key > "/dev/stderr"
      } else {
        seen[key] = 1
        keep[i] = 1
      }
    }
    for (i = 1; i <= n; i++) if (keep[i]) print recs[i]
    printf "T\t%d\t%d\n", n, removed > "/dev/stderr"
  }
' "$HIST" >"$TMP_OUT" 2>"$TMP_DUP"

total=$(awk -F'\t' '$1=="T"{print $2}' "$TMP_DUP")
removed=$(awk -F'\t' '$1=="T"{print $3}' "$TMP_DUP")
removed=${removed:-0}

echo "ファイル   : $HIST"
echo "総レコード : $total"
echo "削除対象   : $removed 件(最新の1件は残す)"
echo

if ((removed == 0)); then
	echo "重複はありません。"
	exit 0
fi

echo "--- 重複しているコマンド一覧(削除される件数が多い順) ---"
awk -F'\t' '$1=="D"{cnt[$3]=$2} END{for(k in cnt) printf "%d\t%s\n", cnt[k], k}' "$TMP_DUP" |
	sort -rn |
	awk -F'\t' '{printf "%5d 件削除  %s\n", $1, $2}'
echo

if ((APPLY == 0)); then
	echo "[ドライラン] ファイルは変更していません。"
	echo "実際に削除するには --apply を付けて再実行してください。"
	exit 0
fi

BACKUP="${HIST}.bak.$(date +%Y%m%d-%H%M%S)"
cp -p "$HIST" "$BACKUP" || {
	echo "バックアップ失敗。中止します。" >&2
	exit 1
}
echo "バックアップ: $BACKUP"

cat "$TMP_OUT" >"$HIST" && echo "完了: 重複を削除しました。"
echo "反映のため、開いているターミナルを閉じるか exec zsh を実行してください。"
