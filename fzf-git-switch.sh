#!/bin/bash
# shellcheck disable=SC2016,SC2155
#
# @fzf https://github.com/junegunn/fzf
# @ripgrep https://github.com/BurntSushi/ripgrep
# @gnu-sed https://www.gnu.org/software/sed/
fzf_git_switch() {
	# ansi color for display only (local=green, remote=red, tag=yellow)
	local GREEN=$'\033[32m'
	local RED=$'\033[31m'
	local YELLOW=$'\033[33m'
	local RESET=$'\033[0m'

	# git refs（一時ファイル・並列化を廃止して直接取得）
	local raw_local=$(git branch --format='%(refname:short)')
	local raw_remote=$(git branch -r 2>/dev/null | rg -v 'HEAD' | awk '{print $NF}')
	local raw_tags=$(git tag --list)

	# 色付け（空なら空文字のまま。下の parts 空判定で除外される）
	local local_branches="" remote_branches="" local_tags="" remote_tags=""
	[[ -n "$raw_local" ]] && local_branches=$(sed "s/^/${GREEN}/;s/$/${RESET}/" <<<"$raw_local")
	[[ -n "$raw_remote" ]] && remote_branches=$(sed "s/^/${RED}/;s/$/${RESET}/" <<<"$raw_remote")
	[[ -n "$raw_tags" ]] && local_tags=$(sed "s/^/${YELLOW}/;s/$/${RESET}/" <<<"$raw_tags")

	# plain (uncolored) list, used to classify the selection by exact-match
	local plain_tags="$raw_tags"

	# support for remote tags
	#remote_tags=$(
	#	git ls-remote --tags origin 2>/dev/null |
	#	awk '$2 !~ /\^{}$/ {sub("refs/tags/", "", $2); print $2}' |
	#	sort -u |
	#	comm -13 <(sort "$tmp3") - 2>/dev/null |
	#	sed "s/^/${YELLOW}/;s/$/${RESET}/"
	#)

	# fzf (collect only non-empty lists so no blank lines are produced)
	local -a parts=()
	[[ -n "$local_branches" ]] && parts+=("$local_branches")
	[[ -n "$remote_branches" ]] && parts+=("$remote_branches")
	[[ -n "$local_tags" ]] && parts+=("$local_tags")
	[[ -n "$remote_tags" ]] && parts+=("$remote_tags")
	[[ ${#parts[@]} -eq 0 ]] && return 0

	local selection=$(
		printf '%s\n' "${parts[@]}" |
			fzf +m --ansi
	)

	# cancel
	[[ -z "$selection" ]] && return 0

	# strip ansi (GNU sed) to recover the real ref name
	local ref=$(printf '%s' "$selection" | sed 's/\x1b\[[0-9;]*m//g')
	[[ -z "$ref" ]] && return 0

	# git switch (classify by exact-match against the plain lists, not by glob)
	if printf '%s\n' "$plain_tags" | rg -qxF -- "$ref"; then
		# tag
		local tag_name="$ref"
		local new_branch="feature/$tag_name"
		echo "tags/$tag_name → $new_branch"

		if git show-ref --quiet "refs/heads/$new_branch"; then
			git switch "$new_branch"
		else
			git switch -c "$new_branch" "refs/tags/$tag_name"
		fi
	elif [[ "$ref" == origin/* ]]; then
		# remote branch (tmp2 stores the full "origin/..." name)
		local branch="${ref#*/}"
		git switch "$branch" 2>/dev/null ||
			git switch -c "$branch" --track "$ref"
	else
		# local branch (pass through as-is; slashes are preserved)
		git switch "$ref"
	fi
}
