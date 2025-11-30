# shell scripts

## [fzf-cd.sh](fzf-cd.sh)

**`cd`** extension shell.

- 無引数で実行するとfzfによるディレクトリ選択UIが起動
- `fd`でサブディレクトリ・シンリンクを検出し、ezaでプレビュー表示
- 選択後自動的に移動し、連続してループ継続可能
- 通常通り引数を渡すと`builtin cd`として標準動作

## [fzf-git-log.sh](fzf-git-log.sh)

**`git log --all --oneline --graph`** extension shell.

- `git log --all --topo-order`のグラフ出力をfzfでフィルタ選択
- 2段階選択: まずコミット、次に該当ファイルを選択
- 選択したファイルのコミット前後差分をdelta(Preview)、VS Codeでdiff比較(`open_editor`関数変更时可対応)

## [fzf-git-switch.sh](fzf-git-switch.sh)

**`git switch`** extension shell.

- ローカル/リモートブランチ・タグを統合表示
- タグを選択:`feature/<tag>`ブランチを自動作成（既存時は切り替え）
- リモートブランチ選択時はtrack付きでcheckout

## [fzf-unity-hub.sh](fzf-unity-hub.sh)

**`Unity Hub`** launch project shell.

- Unity Hubの `projects-v1.json` (jq)をパースしてプロジェクト一覧を表示
- プロジェクト名 / エディタバージョン / favorite / 最終更新日でソート表示
- 選択したプロジェクトに対応するUnityエディタを起動（macOS / Linux / Windows の3プラットフォーム対応）

## Dependencies
- [delta](https://github.com/dandavison/delta)
- [eza](https://github.com/eza-community/eza)
- [fd](https://github.com/sharkdp/fd)
- [fzf](https://github.com/junegunn/fzf)
- [gnu-sed](https://www.gnu.org/software/sed/)
- [jq](https://github.com/jqlang/jq)
- [ripgrep](https://github.com/BurntSushi/ripgrep)
