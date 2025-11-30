# AGENTS.md

## This repo

5 standalone Bash scripts: 4 fzf-based shell functions (`fzf-cd.sh`, `fzf-git-log.sh`, `fzf-git-switch.sh`, `fzf-unity-hub.sh`) and 1 utility (`download.sh`). No build system, tests, CI, or config files exist.

Repo is MIT licensed. Scripts are authored with Japanese comments and English docs.

## Lint & format

No config files; use defaults. All 5 scripts should pass both:

- Lint: `shellcheck fzf-cd.sh fzf-git-log.sh fzf-git-switch.sh fzf-unity-hub.sh download.sh`
- Format check: `shfmt -d *.sh` (empty diff = pass); apply with `shfmt -w *.sh`.
- Indentation is tabs (shfmt default — do not pass `-i`).
- shellcheck passes because the 4 fzf scripts include `# shellcheck disable=SC2016,SC2155`; keep them.

## Usage model (easy to get wrong)

- The 4 `fzf-*.sh` scripts are **sourced** into shell config (`.bashrc`/`.zshrc`), not executed. `download.sh` is the only standalone executable (`./download.sh -u ... -s ... -e ...`; run `-h` for options).
- **File name ≠ function name.** Sourcing defines these functions, which is how users invoke them:
  - `fzf-cd.sh` → `cd` (it **overrides the shell builtin** `cd`; with args it delegates to `builtin cd`, with no args it opens the fzf picker). Preserve this dual behavior on any edit.
  - `fzf-git-log.sh` → `fzf_git_log`, `fzf-git-switch.sh` → `fzf_git_switch`, `fzf-unity-hub.sh` → `fzf_unity_hub`.
- `download.sh`'s internal header comment calls it `download_increment.sh` — cosmetic mismatch, not a second file.

## Dependencies (external binaries, none checked at startup except `curl`)

- fzf scripts: `fzf`, `delta` (git-log only), `eza` (cd only), `fd` (cd only), `ripgrep` (`rg`), `jq` (unity-hub only), plus GNU `sed`/`realpath`.
- `download.sh`: `curl` (only dependency it verifies via `command -v`), plus `bc` and GNU `realpath`.
- **macOS caveat**: scripts assume GNU coreutils on PATH. `fzf-cd.sh` uses `realpath -s` and scripts call `sed` with GNU semantics; BSD defaults (stock macOS) can break them. Install `coreutils`/`gnu-sed` and ensure they shadow the BSD versions.

## Editing gotchas

- `fzf-git-log.sh` hardcodes VS Code diff (`code --wait --diff`) in `EDITOR_CMD`; a commented `vim -d` alternative sits right below it. Change there for other editors.
- `download.sh` uses `set -euo pipefail` and **deletes any file whose download did not return HTTP 200** (`rm -f "$SAVE_PATH"`).
- `fzf-unity-hub.sh` parses Unity Hub's `projects-v1.json` and handles macOS/Linux/Windows paths; the editor path template substitutes `<VERSION>` at runtime.
- `fzf-git-switch.sh` deliberately maps a selected **tag** to a `feature/<tag>` branch (creates it if missing, switches if it exists). Don't "simplify" this tag branch — it's intentional.
