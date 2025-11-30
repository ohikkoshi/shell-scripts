#!/bin/bash
# shellcheck disable=SC2016,SC2155
#
# @eza https://github.com/eza-community/eza
# @fd https://github.com/sharkdp/fd
# @fzf https://github.com/junegunn/fzf
# @gnu-sed https://www.gnu.org/software/sed/
function cd() {
	if [[ "$#" != 0 ]]; then
		builtin cd "$@" || return
		return
	fi

	while true; do
		local directories=$(echo ".." && fd -d 1 -H -I -t d -t l | sed 's|^\./||' | sort)
		local dir="$(
			printf '%s\n' "$directories" |
				fzf --preview '
				__cd_nxt="$(echo {})";
				__cd_path="$(realpath -s "$(pwd)/${__cd_nxt}" 2>/dev/null || echo "$(pwd)/${__cd_nxt}")";
				echo "$__cd_path";
				echo;
				eza -1aF --no-quotes --color=always --icons=auto --group-directories-first "${__cd_path}";
			'
		)"

		[[ ${#dir} != 0 ]] || return 0

		builtin cd "$dir" &>/dev/null || continue
	done
}
