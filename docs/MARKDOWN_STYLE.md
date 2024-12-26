# 📝 Markdown Style Guide

This document outlines the markdown linting rules used in this repository.

## 🔧 Configuration

Our markdown style is enforced using `markdownlint` with custom configurations in `.markdownlint.json`.

## ✅ Enabled Rules

### Document Structure

The following rules ensure consistent document structure:

- `MD001` - Heading levels should increment by one level at a time
- `MD003` - Heading style (ATX style)
- `MD025` - Single H1 heading per file
- `MD047` - Files should end with single newline

### Spacing and Lines

These rules maintain consistent spacing:

- `MD013` - Line length
  - Max length: 100 characters
  - Excludes code blocks and tables
- `MD031` - Blank lines around fenced code blocks
- `MD032` - Blank lines around lists
- `MD047` - Files should end with single newline

### Code Formatting

Code formatting is maintained by these rules:

- `MD038` - Spaces inside code span elements
- `MD040` - Fenced code blocks should have a language specified
- `MD046` - Code block style
  - Uses: "fenced" style
- `MD048` - Code fence style
  - Uses: "backtick" style

### Links and References

Link formatting is controlled by:

- `MD034` - No bare URLs
- `MD042` - No empty links
- `MD051` - Link fragments should be valid
- `MD053` - Link references should be valid

### Content Rules

Content formatting rules include:

- `MD037` - Spaces inside emphasis markers
- `MD039` - Spaces inside link text
- `MD045` - Images should have alt text

## ❌ Disabled Rules

### `MD029` - Ordered list marker style

**Rationale**: We allow mixed list marker styles for better readability and flexibility.

```markdown
1. First item
1. Second item
   - Subitem
   - Subitem
1. Third item
```

### `MD036` - No emphasis in headers

**Rationale**: We use emojis in headers for visual organization.

```markdown
# 🚀 Project Title

## 📝 Documentation
```

### `MD041` - First line in file should be top level heading

**Rationale**: Allows for emojis before first heading.

```markdown
🏠

# Project Title
```

## 🔄 Modified Rules

### `MD024` - Multiple headings with same content

**Rationale**: Allows same heading text at different nesting levels.

```json
"MD024": {
  "allow_different_nesting": true
}
```

### `MD033` - Inline HTML

**Rationale**: Allows `<kbd>` tags for keyboard shortcuts.

```json
"MD033": {
  "allowed_elements": ["kbd"]
}
```

## 💡 Examples

### Correct Heading Structure

Here's an example of correct heading structure:

```markdown
# Main Title

## Section One

### Subsection

## Section Two
```

### Code Blocks

Code blocks should include language specification:

```python
def example():
    return "Hello, World!"
```

### Links and Images

Links and images should follow this format:

```markdown
[Link Text](https://example.com)
![Alt text](./image.png "Image Title")
```

## 🔍 Checking Markdown

To check markdown files against these rules:

```bash
# Check all markdown files
markdownlint "**/*.md"

# Fix auto-fixable issues
markdownlint -f "**/*.md"
```

## 📚 References

For more information, visit:

- [markdownlint Rules](https://github.com/DavidAnson/markdownlint/blob/main/doc/Rules.md)
- [markdownlint-cli](https://github.com/igorshubovych/markdownlint-cli)
