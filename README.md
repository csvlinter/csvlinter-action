# CSV Linter GitHub Action

[![CI](https://img.shields.io/github/actions/workflow/status/csvlinter/csvlinter-action/test.yml?label=CSV%20Linter\&logo=github)](https://github.com/csvlinter/csvlinter-action/actions)

Validate every CSV in your repository with [`csvlinter`](https://github.com/csvlinter/csvlinter) as part of your workflow. The action downloads the requested version of the CLI, expands glob patterns, and surfaces schema / structural errors as workflow annotations.

---

## Quick start

```yaml
# .github/workflows/csvlint.yml
name: CSV Lint
on: [push, pull_request]

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: csvlinter/csvlinter-action@v1   # pin to the major version
```

By default the action scans **all** `**/*.csv` files and fails the job if any are invalid.

### Advanced options

```yaml
- uses: csvlinter/csvlinter-action@v1
  with:
    paths: "data/**/*.csv, reports/*.csv"   # comma‑separated globs
    csvlinter_version: "v1.3.1"            # or "latest"
    schema: "schemas/customer.schema.json"  # override auto‑discovery
    delimiter: ";"                         # e.g. semicolon‑separated files
    fail_fast: "true"                      # stop at first row error
    max_failures: 25                        # cap failing files to keep logs short
```

---

## Inputs

| Input               | Description                                           | Required | Default    |
| ------------------- | ----------------------------------------------------- | -------- | ---------- |
| `paths`             | Glob pattern(s) for CSV files (comma‑separated)       | No       | `**/*.csv` |
| `csvlinter_version` | Version tag to download, or `latest`                  | No       | `latest`   |
| `schema`            | Path to a JSON Schema file (overrides auto‑discovery) | No       | *(empty)*  |
| `delimiter`         | Override delimiter character                          | No       | `,`        |
| `fail_fast`         | Pass `--fail-fast` to csvlinter (`true` / `false`)    | No       | `false`    |
| `max_failures`      | Stop after *N* failing files (`0` = unlimited)        | No       | `0`        |

## Outputs

| Output          | Description                            |
| --------------- | -------------------------------------- |
| `files_checked` | Number of CSV files processed          |
| `errors_found`  | Number of files that failed validation |

---

## FAQ

### How do I pin a csvlinter version?

Set the `csvlinter_version` input to a specific tag (e.g. `v1.3.1`). Omitting it or using `latest` downloads the newest release.

### What about schema resolution?

If you **don’t** set the `schema` input, the action lets csvlinter perform its [built‑in search](https://github.com/csvlinter/csvlinter?tab=readme-ov-file#schema-resolution). Provide `schema:` only when you need a custom file.

### How noisy are the logs?

Successful files print a single `✓ filename.csv` line. Only failures dump full diagnostics. Use `max_failures` to stop after a threshold if your repo contains thousands of broken files.

---

© 2025 csvlinter authors – MIT License
