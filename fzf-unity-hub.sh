#!/bin/bash
# shellcheck disable=SC2016,SC2155
#
# @fzf https://github.com/junegunn/fzf
# @jq https://github.com/jqlang/jq
fzf_unity_hub() {
	local PROJECT_JSON_PATH
	local UNITY_EDITOR_PATH
	local OS

	case "$(uname -s)" in
	Darwin)
		OS='Darwin'
		PROJECT_JSON_PATH="${HOME}/Library/Application Support/UnityHub/projects-v1.json"
		UNITY_EDITOR_PATH="/Applications/Unity/Hub/Editor/<VERSION>/Unity.app/Contents/MacOS/Unity"
		;;
	Linux)
		OS='Linux'
		PROJECT_JSON_PATH="${HOME}/.config/UnityHub/projects-v1.json"
		UNITY_EDITOR_PATH="${HOME}/Unity/Hub/Editor/<VERSION>/Editor/Unity"
		;;
	CYGWIN* | MINGW* | MSYS*)
		OS='Windows'
		PROJECT_JSON_PATH="$(cygpath -u "${APPDATA}/UnityHub/projects-v1.json")"
		UNITY_EDITOR_PATH='C:/Program Files/Unity/Hub/Editor/<VERSION>/Editor/Unity.exe'
		;;
	*)
		exit
		;;
	esac

	if [ ! -f "$PROJECT_JSON_PATH" ]; then
		exit
	fi

	local selected=$(
		jq -r '.data | to_entries[] |
		[
			.value.title,
			.value.version,
			(if .value.isFavorite then "*" else "-" end),
			(.value.lastModified | tonumber / 1000 | strflocaltime("%y/%m/%d %H:%M")),
			.value.path
		] |
		@tsv' "$PROJECT_JSON_PATH" |
			sed "s|$HOME|~|g" |
			while IFS=$'\t' read -r title version favorite modified path; do
				printf "%-24s %-12s %-8s %-14s %-128s\n" "$title" "$version" "$favorite" "$modified" "$path"
			done |
			sort -t' ' -k1,1 |
			fzf --header="$(printf "%-24s %-12s %-8s %-14s %-128s" "Project" "Unity" "Favorite" "Modified" "Path")"
	)

	if [ -n "$selected" ]; then
		local version=$(echo "$selected" | awk '{print $2}')
		local path=$(echo "$selected" | awk '{print $NF}')
		local editor="${UNITY_EDITOR_PATH/<VERSION>/$version}"

		if [[ "$path" == "~"* ]]; then
			path="${HOME}${path#\~}"
		fi

		case "$OS" in
		Darwin | Linux)
			("$editor" -projectPath "$path") &
			disown
			;;
		Windows)
			("$editor" -projectPath "$(cygpath -u "$path")") &
			disown
			;;
		esac
	fi
}
