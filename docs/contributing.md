---
title: Contributing
description: Guidelines for contributing to docker-postgres-snapshot
audience: developers
doc_type: reference
tags: [contributing, development, testing]
lastReviewed: 2026-10-30
version: 1.x
---

# Contributing

Contributions are welcome! Please follow these guidelines when submitting pull requests.

## Quick Checklist

### Code Changes

- [ ] All tests pass locally (`testing/run-tests.sh`)
- [ ] New tests added for new functionality
- [ ] Self-review completed
- [ ] Code commented where necessary

### Documentation Changes

- [ ] Front matter added to new/updated pages (see the PR template)
- [ ] Internal links tested (`mkdocs serve`)
- [ ] Code examples tested
- [ ] New pages added to `mkdocs.yml` nav
- [ ] No hardcoded test counts

## Testing

```bash
cd testing
./run-tests.sh
```

See [Running Tests](running-tests.md) for details.

## Pull Request Template

The full PR checklist is in `.github/PULL_REQUEST_TEMPLATE.md`.
