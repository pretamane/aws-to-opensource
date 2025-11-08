# No Emojis Policy

**Effective Date:** October 10, 2025  
**Policy Status:** ENFORCED

## Policy Statement

This codebase maintains a **strict no-emojis policy**. All documentation, code, scripts, and configuration files must be emoji-free.

## Rationale

1. **Professional Standards** - Enterprise code should be text-only
2. **Compatibility** - Not all terminals/editors display emojis correctly
3. **Accessibility** - Screen readers have issues with emojis
4. **Git Diffs** - Emojis create noise in version control
5. **International Teams** - Plain text is universally understood

## Enforcement

### Automatic Prevention

1. **Pre-commit Hook** - Blocks commits containing emojis
   - Location: `.githooks/pre-commit`
   - Automatically runs on `git commit`

2. **Emoji Check Script** - Scans for emojis
   - Location: `.emoji-check.sh`
   - Run manually: `./emoji-check.sh`

3. **Removal Tool** - Removes all emojis
   - Location: `scripts/remove-emojis.sh`
   - Run: `./scripts/remove-emojis.sh`

### Setup Instructions

To enable automatic emoji prevention:

```bash
# Install the pre-commit hook
ln -s ../../.emoji-check.sh .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit

# Verify installation
ls -la .git/hooks/pre-commit
```

## What to Use Instead

### Instead of Check Marks
- Use: `[OK]`, `[PASS]`, `[DONE]`, `[SUCCESS]`
- Avoid: 

### Instead of Cross Marks  
- Use: `[ERROR]`, `[FAIL]`, `[BLOCKED]`, `[NO]`
- Avoid: 

### Instead of Warning Signs
- Use: `[WARNING]`, `[CAUTION]`, `[NOTE]`
- Avoid: 

### Instead of Icons
- Use descriptive text in brackets: `[ROCKET]`, `[FILE]`, `[TOOLS]`
- Avoid:   

## Examples

### Bad (With Emojis)
```
##  **Quick Start**

-  Feature complete
-  Not working
-  Be careful
```

### Good (No Emojis)
```
## Quick Start

- [DONE] Feature complete
- [BLOCKED] Not working  
- [WARNING] Be careful
```

## Compliance Checklist

Before committing code, ensure:

- [ ] No emojis in README.md
- [ ] No emojis in documentation files
- [ ] No emojis in code comments
- [ ] No emojis in echo/print statements
- [ ] No emojis in log messages
- [ ] Pre-commit hook is installed

## Tools Reference

### Check for Emojis
```bash
./.emoji-check.sh
```

### Remove All Emojis
```bash
./scripts/remove-emojis.sh
```

### Find Emojis Manually
```bash
grep -rP '[-🿿-🿽]|||' --include="*.md" --include="*.yaml" .
```

## Violations

If emojis are found:

1. Pre-commit hook will block the commit
2. Error message shows which files contain emojis
3. Run `./scripts/remove-emojis.sh` to fix automatically
4. Commit again

## Exceptions

**None.** This policy has no exceptions.

## Questions

If you have questions about this policy, refer to:
- This document (NO_EMOJIS_POLICY.md)
- Emoji check script (.emoji-check.sh)
- Removal tool (scripts/remove-emojis.sh)

---

**Last Updated:** October 10, 2025  
**Enforcement:** Automatic via git hooks


