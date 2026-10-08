# Contributing

The most valuable contribution right now is **hardware test results** on a real `lake` device (POCO C75 4G / Redmi 14C 4G), following [`docs/DEVICE-TEST-PROTOCOL.md`](docs/DEVICE-TEST-PROTOCOL.md). Please open an issue with: device model and exact firmware (`ro.build.version.incremental`), which step you ran (Z0/R3/T-1/T2b/T3), `dmesg` and `adb bugreport` excerpts, and the sha256 of every image involved.

Code changes: keep tools read-only on inputs, add a negative (sabotage) test for every new gate, and label claims `MEASURED` (with the command) or `UNVERIFIED`. Never commit partition dumps, boot images, or anything containing device identifiers.
