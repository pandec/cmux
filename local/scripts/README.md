# Scripts

## fetch-github-cache.sh

Fetches open issues, PRs, and recent merged/rejected PRs from `manaflow-ai/cmux` into `.github-cache/` for fast local searching.

### Run

```bash
./local/scripts/fetch-github-cache.sh
```

Requires `gh` CLI authenticated. Takes ~10-15s.

### Output files

| File | Contents | Format |
|---|---|---|
| `local/.github-cache/issues.tsv` | All open issues | `number \t title \t labels \t date \t author \t body_preview` |
| `local/.github-cache/prs.tsv` | All open PRs | `number \t title \t branch \t labels \t date \t author \t +lines \t -lines \t files \t body_preview` |
| `local/.github-cache/prs-merged.tsv` | Last 200 merged PRs | same as prs.tsv |
| `local/.github-cache/prs-rejected.tsv` | Recently closed-not-merged PRs | `number \t title \t branch \t body_preview` |
| `local/.github-cache/.last-fetched` | Timestamp of last fetch | ISO 8601 |

### Search

```bash
grep -i 'emoji'          local/.github-cache/issues.tsv local/.github-cache/prs.tsv
grep -i 'shortcut'       local/.github-cache/issues.tsv
grep -i 'home\|end\|pageup' local/.github-cache/issues.tsv local/.github-cache/prs.tsv
grep -i 'option.*delete' local/.github-cache/issues.tsv
```

`local/` is gitignored.
