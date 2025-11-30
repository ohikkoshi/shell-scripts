#!/bin/bash
# shellcheck disable=SC2016,SC2155
#
# @delta https://github.com/dandavison/delta
# @fzf https://github.com/junegunn/fzf
# @gnu-sed https://www.gnu.org/software/sed/
# @ripgrep https://github.com/BurntSushi/ripgrep
function fzf_git_log() {
	# sed
	local SED_OPTIONS='s/|/┃/g;s/\//∕/g;s/\\/∖/g;s/\*/●/g;s/-/━/g;s/=/═/g'

	# git-delta
	local DELTA_OPTIONS="--dark --syntax-theme=Nord --side-by-side --line-numbers --tabs=4 --hyperlinks --commit-style=omit --hunk-header-decoration-style='blue ul'"
	local DELTA_SYNTAX="\
		--line-numbers-zero-style=gray \
		--line-numbers-minus-style=#BA3737 \
		--line-numbers-plus-style=#37BABA \
		--minus-style='#BA3737 #292c3c' \
		--plus-style='#37BABA #292c3c' \
		--minus-emph-style='#BA3737 #3B1111' \
		--plus-emph-style='#37BABA #113B3B' \
		"

	# editor
	local EDITOR_CMD=(code --wait --diff)
	#local EDITOR_CMD=(vim -d)

	# fzf
	local fzf_output
	local commit_hash
	local commit_file

	while true; do
		# select commit hash
		fzf_output=$(
			git log --all --topo-order --oneline --graph --color=always --date=format:'%y/%m/%d %H:%M' \
				--pretty=format:'%C(yellow ul)%h%C(reset) %C(white ul dim)%ad%C(reset) %C(white ul dim)%cn%C(auto)%d%C(reset)%n%C(white)%s' "$@" |
				sed "$SED_OPTIONS" |
				fzf --bind='enter:transform:(grep -q "[a-f0-9]\{7\}" <<< {}) && echo accept || echo ignore' \
					--ansi --no-sort --reverse --tiebreak=index \
					--preview-window=right:50% \
					--preview 'grep -o "[a-f0-9]\{7\}" <<< {} | head -1 | xargs -I % git show --name-status --color=always %'
		) || return

		# <ESC>: quit
		commit_hash=$(rg -o "[a-f0-9]{7}" --color=never <<<"$fzf_output" | head -1)
		[[ -z "$commit_hash" ]] && continue

		while true; do
			# select commit file
			commit_file=$(
				git diff-tree --no-commit-id --name-only -r "$commit_hash" |
					fzf --bind 'scroll-up:preview-up,scroll-down:preview-down' \
						--preview-window=right:80% \
						--preview="git show -U8 --no-prefix --color=always $commit_hash -- {} | delta $DELTA_OPTIONS $DELTA_SYNTAX --width=\$FZF_PREVIEW_COLUMNS"
			) || break

			# <ESC> back
			[[ -z "$commit_file" ]] && continue

			# create temporary files
			local file_ext="${commit_file##*/}" && file_ext="${file_ext##*.}"
			[[ -z "$file_ext" || "$file_ext" == "${commit_file##*/}" ]] && file_ext="txt"

			local temp_before=$(mktemp "/tmp/git-diff-before.XXXXXX.${file_ext}")
			local temp_after=$(mktemp "/tmp/git-diff-after.XXXXXX.${file_ext}")

			# get file content before and after the commit
			git show "$commit_hash~1:$commit_file" >"$temp_before" 2>/dev/null || : >"$temp_before"
			git show "$commit_hash:$commit_file" >"$temp_after" 2>/dev/null || : >"$temp_after"

			# open editor
			"${EDITOR_CMD[@]}" "$temp_before" "$temp_after"

			# cleanup temporary files
			rm -f "$temp_before" "$temp_after"
		done
	done
}
