# Smart Society Management Application

Flutter + Firebase residential society management system.

## Documentation

Read these files in this order:

1. `PROJECT_PLAN.md` — complete product specification and phased implementation plan
2. `ARCHITECTURE.md` — technical architecture and development rules
3. `PROJECT_STATUS.md` — current implementation state
4. `CHANGELOG.md` — history of meaningful changes

## Antigravity

At the beginning of every Antigravity session:

> Read `PROJECT_PLAN.md`, `ARCHITECTURE.md`, `PROJECT_STATUS.md`, and `CHANGELOG.md`. Inspect the current Git working tree and existing implementation. Determine the current phase and what other developers have already implemented. Do not overwrite working code or duplicate existing functionality. Continue only with the requested task. Follow all project architecture, security, UI, testing, and Git rules.

## Multi-Developer Workflow

Before work:

```bash
git checkout main
git pull origin main
git checkout -b feature/<feature-name>
```

After work:

```bash
git status
git add .
git commit -m "feat: <description>"
git push -u origin feature/<feature-name>
```

Create a Pull Request and merge after review.

After merging, other developers should pull the latest `main` before continuing.

## Important Rule

The Markdown files are the project's source of truth for requirements and development state.

The codebase is the source of truth for what is actually implemented.

If documentation and code disagree:
1. Inspect the code.
2. Determine the actual state.
3. Update the documentation.
4. Do not blindly rewrite working code.
