# Balance fixture runner

The runner is dependency-free and deterministic. It uses a fixed `0.01` second
simulation tick and seed, reads the shipped Lua definitions, and emits stable
JSON (including damage and kills) to stdout.

Regenerate the documented tables:

```sh
python3 tools/balance/run_fixtures.py --write-docs
```

Only report role/efficiency regressions (silent success, non-zero on failure):

```sh
python3 tools/balance/run_fixtures.py --check
```

Run without flags to obtain the complete machine-readable capture. The
`definition_sha256` field fingerprints the tower, enemy, branch, module, and
difficulty sources used by the capture.
