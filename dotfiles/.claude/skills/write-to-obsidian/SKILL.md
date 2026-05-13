---
name: write-to-obsidian
description: Write or append content to files in the Obsidian vault at ~/Documents/Home/. Use when saving briefings, meeting prep, notes, or any structured output to Obsidian. Triggers on "save to obsidian", "write to obsidian", "export to obsidian", "save note", "write note".
user_invocable: false
codex-compatible: false
---

## Contract
Consumes: content to save (briefings, meeting prep, notes, structured output)
Produces: Obsidian vault file(s) at ~/Documents/Home/
Requires: filesystem access to ~/Documents/Home/
Side effects: creates/appends files in Obsidian vault
Human gates: none (checks for existing files and asks before overwriting)

## Context
Typical workflows: output persistence (after any skill that produces notes, briefings, or structured content)
Pairs well with: slack-update, any skill producing saveable output

# Write to Obsidian

Write markdown files to the Obsidian vault at `~/Documents/Home/`.

## Vault Root

```
~/Documents/Home/
```

## Key Locations

| Purpose | Path (relative to vault root) |
|---------|-------------------------------|
| Briefings | `Chief of Staff/Briefings/[YYYY-MM]/[MM-DD]/` |
| Meeting prep | `Chief of Staff/Briefings/[YYYY-MM]/[MM-DD]/` |
| Meeting notes | `Areas/dojo/Meeting Notes/` |
| Meal plans | `Areas/Family/Meal Planning/[YYYY]/[MM-month]/` |
| Shopping lists | `Areas/Family/Meal Planning/[YYYY]/[MM-month]/` |
| Inbox / scratch | `* Inbox/` |

## How to Write

The filesystem MCP server does NOT have access to the vault path. Always use bash heredoc:

```bash
mkdir -p ~/Documents/Home/path/to/directory && cat > ~/Documents/Home/path/to/directory/filename.md << 'OBSIDIAN_EOF'
---
created: YYYY-MM-DD
tags: [tag1, tag2]
---

# Title

Content here
OBSIDIAN_EOF
```

## Rules

1. **Always `mkdir -p`** the target directory before writing.
2. **Use `<< 'OBSIDIAN_EOF'`** (quoted) to prevent shell variable expansion in content.
3. **Include YAML frontmatter** with at least `created` date and relevant `tags`.
4. **Never overwrite without asking.** Before writing, check if the file exists:
   ```bash
   [ -f ~/Documents/Home/path/to/file.md ] && echo "EXISTS" || echo "NEW"
   ```
   If it exists, ask the user whether to overwrite or append.
5. **To append** instead of overwrite, use `>>` instead of `>`:
   ```bash
   cat >> ~/Documents/Home/path/to/file.md << 'OBSIDIAN_EOF'

   ## New Section

   Appended content
   OBSIDIAN_EOF
   ```

## File Naming

- Lowercase with hyphens for generated files: `morning-briefing.md`, `will-powers-1on1-prep.md`
- Match existing naming if adding to an existing folder
- Date-stamped directories for recurring outputs: `Briefings/2026-03/03-16/`

## Briefing-Specific Conventions

| Output Type | Filename | Directory |
|-------------|----------|-----------|
| Morning briefing | `morning-briefing.md` | `Chief of Staff/Briefings/[YYYY-MM]/[MM-DD]/` |
| 1:1 prep | `[name]-1on1-prep.md` | `Chief of Staff/Briefings/[YYYY-MM]/[MM-DD]/` |
| Meeting prep | `[meeting-slug]-prep.md` | `Chief of Staff/Briefings/[YYYY-MM]/[MM-DD]/` |

## Example: Write a briefing

```bash
mkdir -p ~/Documents/Home/Chief\ of\ Staff/Briefings/2026-03/03-16 && cat > ~/Documents/Home/Chief\ of\ Staff/Briefings/2026-03/03-16/morning-briefing.md << 'OBSIDIAN_EOF'
---
created: 2026-03-16
tags: [briefing, morning]
---

# Morning Briefing — March 16, 2026

Content here...
OBSIDIAN_EOF
```

## NORA (Meal Planning) Conventions

Directory: `Areas/Family/Meal Planning/[YYYY]/[MM-month]/`
- `[MM-month]` uses zero-padded month + lowercase name: `03-march`, `11-november`

| Output Type | Filename | Tags |
|-------------|----------|------|
| Weekly meal plan | `meal-plan-week-of-[MM-DD].md` | `[meal-plan, nora]` |
| Shopping list | `shopping-list-week-of-[MM-DD].md` | `[shopping-list, nora]` |

### Meal plan format

```bash
mkdir -p ~/Documents/Home/Areas/Family/Meal\ Planning/2026/03-march && cat > ~/Documents/Home/Areas/Family/Meal\ Planning/2026/03-march/meal-plan-week-of-03-16.md << 'OBSIDIAN_EOF'
---
created: 2026-03-16
week_start: 2026-03-16
tags: [meal-plan, nora]
---

# Meal Plan — Week of March 16, 2026

## Monday

### Breakfast
**Recipe Name**
- Ingredient 1 (amount)
- Ingredient 2 (amount)

> Nutrition per serving: X cal | Xg protein | Xg carbs | Xg fat

### Lunch
...

### Dinner
...
OBSIDIAN_EOF
```

### Shopping list format

```bash
cat > ~/Documents/Home/Areas/Family/Meal\ Planning/2026/03-march/shopping-list-week-of-03-16.md << 'OBSIDIAN_EOF'
---
created: 2026-03-16
week_start: 2026-03-16
tags: [shopping-list, nora]
---

# Shopping List — Week of March 16, 2026

## Produce
- [ ] Item (amount)

## Protein
- [ ] Item (amount)

## Dairy
- [ ] Item (amount)

## Pantry
- [ ] Item (amount)

## Frozen
- [ ] Item (amount)
OBSIDIAN_EOF
```
