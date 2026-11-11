# Contributing

Thanks for helping. Bug reports, corrections with evidence, new eval cases and new recipes are all welcome.

## Layout

```text
.claude-plugin/             plugin and marketplace manifests
skills/<name>/SKILL.md      the skill: frontmatter description + body
skills/<name>/references/   detail the skill loads on demand
skills/<name>/evals/        eval cases (prompt, input files, graders)
```

## Ground rules

- **Cite the source of a value.** Apple first (SDK behaviour, WWDC, the HIG, measured system behaviour), then the best-evidenced source. Keep the skills' split: Apple's guidance is stated as Apple's, house values are labelled guidelines with a reason. Don't change a number without saying where the new one comes from.
- **Typecheck every Swift block you add or edit** at the deployment target it's marked with (iOS 17 unless marked 18, 26, 27 or 27.1).
- **Keep the skills consistent.** A value that appears in more than one skill (spring presets, frequency tiers, haptic rules) changes everywhere or nowhere.
- **Keep SKILL.md lean.** Put detail in `references/` and point to it from the body.

## Running evals

From a skill's directory:

```bash
cd skills/swift-motion-animate
claude plugin eval . --scaffold --allow-tools Write Edit Bash
```

`--scaffold` runs the case's `place-files.sh` to copy its input files in; `--allow-tools` grants the gated tools (Write, Edit, Bash) the cases need. Results go to the skill's `evals/results/`, which is gitignored. Use `--case <glob>` to run one case and `--runs <n>` to change the number of runs (default 3 per arm). The report is published to claude.ai unless you pass `--no-publish`.

If your change affects behaviour, include before/after eval scores in the pull request. To add a case, copy an existing one under `evals/`: a `case.yaml`, a `prompt.md`, the input `files/`, a `place-files.sh`, and one grader per behaviour in `graders/`.

## Pull requests

Keep them focused: one fix or one addition per PR, with a sentence on why. By contributing you agree your work is released under the [MIT License](LICENSE).
