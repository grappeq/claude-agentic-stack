---
description: Language-agnostic quality gate — sync the working tree to the sandbox VM, then run the project's build, lint/type-check, and tests there over SSH.
---

The host is permission-limited, so **builds and tests run on the sandbox VM** (SSH alias `sandbox`), never on the host.

1. **Reachability.** Confirm the VM is up: `ssh sandbox true`. If it fails, STOP and report — do not fall back to building on the host.

2. **Sync** the working tree to the VM:
   ```
   rsync -az --delete --exclude '.git/' --exclude 'node_modules/' --exclude 'target/' --exclude '.venv/' ./ sandbox:"$SANDBOX_REMOTE_DIR"/
   ```
   If `rsync` isn't on the host, fall back to `scp -r` or `git archive HEAD | ssh sandbox "mkdir -p $SANDBOX_REMOTE_DIR && tar -x -C $SANDBOX_REMOTE_DIR"`.

3. **Detect & run on the VM.** Detect the project type from its manifests and run the build, lint/type-check, and tests **over SSH**:
   ```
   ssh sandbox "cd $SANDBOX_REMOTE_DIR && <commands>"
   ```
   (Use **double** quotes so the host expands `$SANDBOX_REMOTE_DIR` while the literal `~` is expanded by the VM; the inner command still runs as one `ssh` call.)
   Prefer the project's own scripts (package.json `scripts`, a Makefile, `pyproject.toml` config) over the generic defaults below. Run what exists; skip what doesn't.

   | Manifest present | Commands to run on the VM |
   |------------------|---------------------------|
   | `package.json` | install (match the lockfile: npm / pnpm / yarn); then the `lint`, `typecheck` (or `tsc --noEmit`), `test`, and `build` scripts that exist |
   | `pyproject.toml` / `requirements.txt` | `ruff check .` (or flake8); `mypy` if configured; `pytest` — use `uv run` or the project venv if present |
   | `go.mod` | `go build ./...`, `go vet ./...`, `go test ./...` |
   | `Cargo.toml` | `cargo build`, `cargo clippy`, `cargo test` |
   | `pom.xml` | `mvn -q verify` |
   | `build.gradle` / `build.gradle.kts` | `./gradlew check` |
   | `Makefile` with lint/test targets | `make lint`, `make test` |

   If no recognized manifest exists, say so and report that there is nothing to verify.

4. Report each step's pass/fail. End with an overall verdict on its own line: `VERIFY: PASS`, or `VERIFY: FAIL` followed by the failing step(s) and the relevant output.
