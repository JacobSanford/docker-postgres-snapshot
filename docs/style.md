# Documentation Style Guide

This brief style guide ensures consistency across the docker-postgres-snapshot documentation.

## Product Naming

**Canonical Name:** `docker-postgres-snapshot`

Use this exact form in all documentation.

## Front Matter

All `.md` files must include complete YAML front matter:

```yaml
---
title: Page Title
description: One-sentence summary of the page content
audience: users|operators|developers
doc_type: tutorial|howto|explanation|reference|guide|landing|quickstart
tags: [keyword1, keyword2, keyword3]
lastReviewed: YYYY-MM-DD
version: 1.x
---
```

**Required fields:**

- `title`: Descriptive page title
- `description`: Brief one-sentence summary
- `audience`: Target reader (users, operators, or developers)
- `doc_type`: Documentation type following Diátaxis framework
- `tags`: Array of relevant keywords
- `lastReviewed`: ISO date of last review
- `version`: Product version (currently `1.x`)

## Headings

**Capitalization:** Use sentence case with key terms capitalized

Examples:

- ✓ `## Docker Compose Examples`
- ✓ `## Structure-Only Tables`
- ✓ `## PostgreSQL Connection Parameters`
- ✗ `## docker compose examples` (too lowercase)
- ✗ `## DOCKER COMPOSE EXAMPLES` (too uppercase)

**Hierarchy:** Do not skip heading levels (h2 → h4)

## Code Blocks

Always specify the language for syntax highlighting:

````markdown
```bash
docker run --rm ghcr.io/jacobsanford/postgres-snapshot:1.x daily
```

```yaml
services:
  postgres-snapshot:
    image: ghcr.io/jacobsanford/postgres-snapshot:1.x
```

```json
{
  "snapshot_time": "2025-11-16T12:00:00Z"
}
```
````

**Supported languages:** `bash`, `yaml`, `json`, `sql`, `text`

## Links

**External links:** Always use `{target="_blank"}` to open in new tabs

```markdown
[Docker](https://www.docker.com){target="_blank"}
[PostgreSQL](https://www.postgresql.org){target="_blank"}
```

**Internal links:** Use relative paths without `{target="_blank"}`

```markdown
[Configuration Reference](configuration.md)
[Quick Start](quickstart.md)
```

**Link text:** Use descriptive text, avoid "click here" or bare URLs

- ✓ `See the [Configuration Reference](configuration.md) for details`
- ✗ `Click [here](configuration.md) for more information`

## Inline Code

Use backticks for:

- File paths: `` `/data` ``, `` `snapshot.sh` ``
- Environment variables: `` `DB_HOSTNAME` ``, `` `RSNAPSHOT_RETAIN_HOURLY` ``
- Commands: `` `docker compose run` ``
- Code references: `` `pg_dump` ``, `` `rsnapshot` ``

## Admonitions

Use MkDocs admonitions for important information:

```markdown
!!! warning "Your Responsibility"
    This package should be considered an example rather than production-ready.

!!! note "Tip"
    Higher compression levels reduce file size but increase CPU usage.
```

**Common types:** `warning`, `note`, `tip`, `info`

## Tables

Use pipe tables with header separators:

```markdown
| Variable | Description | Default |
|----------|-------------|---------|
| `DB_HOSTNAME` | Database server hostname | `localhost` |
| `DB_PORT` | Database server port | `3306` |
```

## Tone and Voice

**Style:** Professional, technical, directive

- Use active voice: ✓ "Configure the database hostname" vs. ✗ "The database hostname should be configured"
- Be direct and concise
- Assume reader has Docker and database familiarity
- Avoid excessive pleasantries or conversational asides

## File Organization

**New pages:**
1. Create the `.md` file in `docs/`
2. Add complete front matter
3. Add to navigation in `mkdocs.yml`
4. Include cross-references to related pages

**Images:**
- Store in `docs/images/`
- Optimize to <500 KB
- Always include descriptive alt text
