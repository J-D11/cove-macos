# Cove Project Guidance

- Preserve the existing SwiftPM macOS architecture, naming, native design language, and local-first behavior.
- Keep changes small, focused, testable, and compatible with the stable `dist/QuietDeck.app` permission path.
- Preserve all existing untracked files and unrelated user work.
- Keep build and test output in local log files, and print only concise pass or fail summaries into the conversation.
- Use at most one tightly cropped local visual under 1 MB, and only when visual inspection is essential.
- Never place full-display captures, binaries, archives, or large diffs into model context.
- Checkpoint applied changes before beginning optional polish.
- Avoid network tools unless the user explicitly requires them.
- Never pass local filesystem paths to web search or use `site:` queries for local files. Read local project and memory files with bounded `rg` or `sed` commands instead.
- If a turn fails after a tool request, resume from the current working tree without replaying completed edits or repeating the failed request.
- Use `apply_patch` for source and documentation edits.
- Run `swift test`, plist validation, signed bundle verification, and a one-process launch check before packaging a release.
