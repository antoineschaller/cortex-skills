# Troubleshooting Guide

Common issues and solutions for the engineering-standards skill.

## Table of Contents

1. [Validation Issues](#validation-issues)
2. [Bootstrap Issues](#bootstrap-issues)
3. [Pattern Extraction Issues](#pattern-extraction-issues)
4. [Template Issues](#template-issues)
5. [Script Execution Issues](#script-execution-issues)
6. [CI/CD Integration Issues](#cicd-integration-issues)

## Validation Issues

### Issue: Validation fails to find config files in monorepo

**Symptom**:
```
✗ ESLint configuration file
   Not found
✗ Vitest configuration file
   Not found
```

**Cause**: Config files are in `apps/web/` but validator checks root.

**Solution**: The validator now checks multiple locations automatically. If still not found:

1. Verify file exists:
   ```bash
   ls -la apps/web/vitest.config.ts
   ls -la apps/web/eslint.config.mjs
   ```

2. If files exist, this is a validation script bug. Report it.

3. Workaround: Symlink configs to root:
   ```bash
   ln -s apps/web/vitest.config.ts vitest.config.ts
   ln -s apps/web/eslint.config.mjs eslint.config.mjs
   ```

### Issue: False positive for migration idempotency

**Symptom**:
```
✗ All migrations are idempotent
   Issues in 193 files: CREATE POLICY without DO $$ block
```

**Cause**: Migrations use non-standard idempotency patterns.

**Investigation**:
```bash
# Check a specific migration
cat apps/web/supabase/migrations/20251118160000_create_user_signatures_table.sql | grep "CREATE POLICY" -A 5
```

**Solutions**:

1. **If migrations ARE idempotent** (using different pattern):
   - This may be a limitation of the validator
   - File an issue to support your pattern
   - Use `--dry-run` to see which patterns are detected

2. **If migrations are NOT idempotent** (common issue):
   - Fix migrations to use idempotent patterns:
   ```sql
   -- ❌ Non-idempotent
   CREATE POLICY "policy_name" ON table_name ...;

   -- ✅ Idempotent
   DO $$
   BEGIN
     IF NOT EXISTS (
       SELECT 1 FROM pg_policies WHERE policyname = 'policy_name'
     ) THEN
       CREATE POLICY "policy_name" ON table_name ...;
     END IF;
   END $$;
   ```

### Issue: Low compliance score for production project

**Symptom**:
```
Overall Compliance: 32.9% (Grade: F)
```

**Diagnosis**:
```bash
# Run validation and save output
python3 scripts/validate-compliance.py \
  --project-path . \
  --report-format json \
  --output diagnosis.json

# Check what's failing
cat diagnosis.json | jq '.categories[] | select(.score < 50)'
```

**Common causes**:

1. **Missing CLAUDE.md**: Add minimal file:
   ```bash
   cat > CLAUDE.md <<EOF
   # Project Name

   ## Tech Stack
   [List your stack]

   ## Critical Rules
   1. [Your rules]
   EOF
   ```

2. **No hooks configured**: Bootstrap lefthook:
   ```bash
   pnpm add -D lefthook
   # Copy template from engineering-standards
   cp /path/to/templates/lefthook.yml.template lefthook.yml
   pnpm lefthook install
   ```

3. **Missing quality tools**: Install essentials:
   ```bash
   pnpm add -D eslint prettier typescript @typescript-eslint/eslint-plugin
   # Add configs from templates
   ```

### Issue: Validation hangs or takes too long

**Symptom**: Validation doesn't complete after 30+ seconds.

**Cause**: Large codebase with many files.

**Solutions**:

1. **Skip heavy checks**: Edit script temporarily
2. **Limit file scanning**: Use `.gitignore` patterns
3. **Run quick check instead**:
   ```bash
   ./scripts/check-standards.sh .  # < 5 seconds
   ```

## Bootstrap Issues

### Issue: Bootstrap fails with "Output path already exists"

**Symptom**:
```
❌ Error: Output path already exists: /path/to/project
```

**Solution**:

1. **Remove existing directory**:
   ```bash
   rm -rf /path/to/project
   ```

2. **Or choose different path**:
   ```bash
   python3 scripts/bootstrap-project.py \
     --project-name "My App" \
     --project-type nextjs \
     --output-path /path/to/my-app-v2
   ```

### Issue: Template substitution not working

**Symptom**: Files contain `{{project_name}}` instead of actual name.

**Cause**: Variable not defined in bootstrap script.

**Solution**:

1. **Check bootstrap script** supports the variable
2. **Manual replacement** as workaround:
   ```bash
   cd /path/to/project
   find . -type f -name "*.md" -o -name "*.json" -o -name "*.yml" \
     | xargs sed -i '' 's/{{project_name}}/My Actual Name/g'
   ```

### Issue: Git initialization fails

**Symptom**:
```
⚠ Git initialization failed: not a git repository
```

**Cause**: Project directory not empty or git not in PATH.

**Solutions**:

1. **Check git is installed**:
   ```bash
   which git
   git --version
   ```

2. **Initialize manually**:
   ```bash
   cd /path/to/project
   git init
   git add .
   git commit -m "chore: initial commit

   Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
   ```

### Issue: Lefthook installation fails during bootstrap

**Symptom**:
```
⚠ Lefthook hooks installation failed
```

**Cause**: Lefthook not installed or not in PATH.

**Solutions**:

1. **Install lefthook**:
   ```bash
   pnpm add -D lefthook
   ```

2. **Install hooks manually**:
   ```bash
   cd /path/to/project
   pnpm lefthook install
   ```

### Issue: Bootstrapped project has low compliance

**Symptom**: Validation shows < 95% compliance after bootstrap.

**Expected**: Bootstrap should create 95%+ compliant project.

**Diagnosis**:
```bash
# Validate immediately after bootstrap
python3 scripts/validate-compliance.py \
  --project-path /path/to/bootstrapped/project

# Should show 95%+. If not, file a bug report.
```

**Workaround**: Manually add missing files/configs reported by validation.

## Pattern Extraction Issues

### Issue: Sync finds no patterns

**Symptom**:
```
📊 Total Patterns Extracted: 0
```

**Causes**:

1. **Wrong project path**:
   ```bash
   # Verify path is correct
   ls /path/to/source/project
   # Should show source code
   ```

2. **Project doesn't have standard files**:
   ```bash
   # Check for expected files
   ls /path/to/source/project/lefthook.yml
   ls /path/to/source/project/vitest.config.ts
   ```

**Solution**: Ensure source project actually uses the patterns you're trying to extract.

### Issue: Pattern extraction crashes

**Symptom**:
```
Traceback (most recent call last):
  File "scripts/sync-from-project.py", line XXX
```

**Causes**:

1. **Malformed configuration file** in source project
2. **Binary file** encountered during scan
3. **Permission denied** on some files

**Solutions**:

1. **Run with Python error details**:
   ```bash
   python3 -u scripts/sync-from-project.py \
     --source-project /path \
     --extract all
   ```

2. **Check file permissions**:
   ```bash
   find /path/to/source -type f ! -readable
   ```

3. **Skip problematic files**: Edit script to add try/except

### Issue: Many "new patterns" found that shouldn't be new

**Symptom**:
```
✨ NEW PATTERNS FOUND (51):
+ HOOKS: Pre-commit hook: format  # This should be in standards
```

**Cause**: Pattern comparison is too strict or patterns are documented differently.

**Investigation**:
```bash
# Check if pattern is in standards
grep -r "Pre-commit hook: format" /path/to/engineering-standards/*.md
```

**Solutions**:

1. **This is expected**: Standards may not document every variation
2. **Improve pattern matching**: Update comparison logic in script
3. **Ignore for now**: Focus on genuinely new patterns

## Template Issues

### Issue: Template missing required variables

**Symptom**: Template file has `{{undefined_var}}` that's not substituted.

**Solution**:

1. **Check project-variables.json** for available variables
2. **Add variable** to bootstrap script if missing
3. **Use existing variable**: Replace with documented one

### Issue: Template doesn't match project structure

**Symptom**: CLAUDE.md template references `src/` but project uses `app/`.

**Solution**:

1. **Manual edit after bootstrap**:
   ```bash
   cd /path/to/project
   sed -i '' 's/src\//app\//g' CLAUDE.md
   ```

2. **Use different project type**:
   ```bash
   # Next.js uses app/
   --project-type nextjs

   # Generic uses src/
   --project-type backend
   ```

## Script Execution Issues

### Issue: Permission denied

**Symptom**:
```
bash: ./scripts/check-standards.sh: Permission denied
```

**Solution**:
```bash
chmod +x scripts/*.sh scripts/*.py
```

### Issue: Python ModuleNotFoundError

**Symptom**:
```
ModuleNotFoundError: No module named 'dataclasses'
```

**Cause**: Python version too old.

**Solution**:

1. **Check Python version**:
   ```bash
   python3 --version
   # Need 3.7+
   ```

2. **Upgrade Python** or use pyenv:
   ```bash
   pyenv install 3.11
   pyenv global 3.11
   ```

### Issue: Script path issues

**Symptom**:
```
FileNotFoundError: [Errno 2] No such file or directory: 'config/rules-config.json'
```

**Cause**: Running script from wrong directory.

**Solution**:

1. **Always run from engineering-standards root**:
   ```bash
   cd /path/to/engineering-standards
   python3 scripts/validate-compliance.py --project-path /other/path
   ```

2. **Or use absolute paths**:
   ```bash
   python3 /absolute/path/to/scripts/validate-compliance.py \
     --project-path .
   ```

### Issue: JSON parsing error

**Symptom**:
```
json.decoder.JSONDecodeError: Expecting value: line 1 column 1 (char 0)
```

**Cause**: Invalid JSON in config file or source project.

**Solution**:

1. **Validate JSON**:
   ```bash
   cat config/rules-config.json | jq .
   ```

2. **Fix JSON syntax**:
   - Remove trailing commas
   - Ensure proper quotes
   - Validate with JSON linter

## CI/CD Integration Issues

### Issue: GitHub Actions can't find scripts

**Symptom**:
```
Error: scripts/validate-compliance.py not found
```

**Cause**: Scripts not checked out in CI environment.

**Solution**:

1. **Clone engineering-standards in workflow**:
   ```yaml
   - name: Clone engineering-standards
     run: |
       git clone https://github.com/your-org/cortex-skills.git /tmp/cortex-skills

   - name: Run validation
     run: |
       python3 /tmp/cortex-skills/templates/skills/engineering-standards/scripts/validate-compliance.py \
         --project-path .
   ```

2. **Or add as git submodule**:
   ```bash
   git submodule add https://github.com/your-org/cortex-skills.git .cortex-skills
   ```

### Issue: CI validation passes but local fails

**Symptom**: CI shows green checkmark but local validation fails.

**Causes**:

1. **Different file state**: CI uses committed files, local may have uncommitted changes
2. **Different environment**: CI may have different Python version
3. **Cached results**: CI may be using cached validation

**Solutions**:

1. **Match local to CI**:
   ```bash
   git stash  # Stash local changes
   python3 scripts/validate-compliance.py --project-path .
   ```

2. **Check CI logs** for exact command and environment
3. **Clear CI cache** and re-run

### Issue: Compliance threshold too strict/loose

**Symptom**: Want to require 90% instead of 80%.

**Solution**:

1. **Modify CI workflow**:
   ```yaml
   - name: Check compliance threshold
     run: |
       SCORE=$(cat compliance.json | jq -r '.overall_score')
       if (( $(echo "$SCORE < 90" | bc -l) )); then
         echo "❌ Compliance below 90% threshold (got $SCORE%)"
         exit 1
       fi
   ```

2. **Or use exit codes** (validation script):
   - Exit 0: 95%+ (Grade A)
   - Exit 1: 70-94% (Grade B-C)
   - Exit 2: <70% (Grade D-F)

## Getting Help

### Debug Mode

Enable verbose output:

```bash
# Bash scripts
bash -x scripts/check-standards.sh .

# Python scripts
python3 -u scripts/validate-compliance.py --project-path . 2>&1 | tee debug.log
```

### Reporting Issues

When reporting issues, include:

1. **Script output** (full error message)
2. **Command used** (exact command line)
3. **Environment info**:
   ```bash
   python3 --version
   git --version
   uname -a
   ```
4. **Minimal reproduction** (if possible)

### Community Resources

- [GitHub Issues](https://github.com/antoineschaller/cortex-skills/issues)
- [USAGE.md](USAGE.md) - Comprehensive usage guide
- [README.md](README.md) - Architecture and overview
- Individual guides - Detailed standards documentation

---

**Last Updated**: 2026-01-13
