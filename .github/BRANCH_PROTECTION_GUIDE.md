# GitHub Branch Protection Setup Guide

## Overview

This guide explains how to configure branch protection rules in your GitHub repository while maintaining full access as the solo developer.

## Files Created

1. **`.github/CODEOWNERS`**: Defines code ownership (currently just you)
2. **`SECURITY.md`**: Security policy and reporting procedures
3. **`.github/workflows/infrastructure-checks.yml`**: Automated CI/CD checks
4. **`.pre-commit-config.yaml`**: Updated with commit message linting (commented out)

## Configuration Steps

### 1. Enable GitHub Actions

Your repository is ready to use GitHub Actions. The workflow will automatically run on:
- Pull requests touching terraform files
- Pushes to main or feat-* branches

No configuration needed - push the files and GitHub Actions will activate.

### 2. Configure Branch Protection (Optional for Solo Dev)

Since you're the only developer, strict branch protection is optional. However, here's how to set it up for future scaling:

**Navigate to**: Repository Settings > Branches > Add branch protection rule

**For `main` branch**:

```
Branch name pattern: main

☑️ Require a pull request before merging
   ☑️ Require approvals: 1 (you can approve your own PRs)
   ☑️ Dismiss stale pull request approvals when new commits are pushed
   ☐ Require review from Code Owners (keep unchecked for now)

☑️ Require status checks to pass before merging
   ☑️ Require branches to be up to date before merging
   Select checks:
   - Terraform Validation
   - Security Scanning
   - Linting
   - Documentation Validation

☐ Require conversation resolution before merging (optional)

☑️ Require signed commits (recommended, not required)

☐ Include administrators (UNCHECK THIS - gives you bypass permission)

☑️ Restrict who can push to matching branches
   Add: Al-Serhan (or leave empty for admin access)

☑️ Allow force pushes
   ☑️ Specify who can force push: Al-Serhan (for emergencies)

☐ Allow deletions
```

### 3. Solo Developer Settings (Recommended)

For your current workflow, use these minimal settings:

```
☑️ Require status checks to pass before merging
   Select: Security Scanning (optional - informational only)

☐ Include administrators (UNCHECKED - full access)

☑️ Allow force pushes
   ☑️ Specify who can force push: Al-Serhan
```

This gives you informational security checks without blocking your work.

### 4. Commit Message Linting

The conventional commits hook is included but commented out in `.pre-commit-config.yaml`.

**To enable it:**
```bash
# Edit .pre-commit-config.yaml
# Uncomment the conventional-pre-commit hook section
pre-commit install --hook-type commit-msg
```

**Commit format when enabled:**
```
feat(terraform): add private VM module
fix(bastion): correct security group rules
docs(readme): update deployment instructions
chore(deps): update pre-commit hooks
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation
- `style`: Formatting
- `refactor`: Code restructuring
- `test`: Testing
- `chore`: Maintenance
- `ci`: CI/CD changes
- `perf`: Performance

### 5. CODEOWNERS Configuration

The `.github/CODEOWNERS` file is set up with you as the owner of all paths.

**When adding team members:**
```
# Edit .github/CODEOWNERS
/terraform/modules/ @Al-Serhan @teammate1
/terraform/environments/prod/ @Al-Serhan @security-team
```

Then enable "Require review from Code Owners" in branch protection.

### 6. Security Considerations

**Current state**: All security files point to you as the owner
**When production-ready**:
1. Enable GPG signing for commits
2. Add security contact email to SECURITY.md
3. Set up AWS CloudTrail and GuardDuty
4. Enable GitHub Security Advisories
5. Enable Dependabot alerts

### 7. Infracost Integration (Optional)

To enable cost estimates in PRs:

1. Sign up at https://www.infracost.io
2. Get API key
3. Add to repository secrets: Settings > Secrets > New repository secret
   - Name: `INFRACOST_API_KEY`
   - Value: your API key
4. Cost estimates will appear in PR comments

## Workflow

### Current (Solo Developer)
```bash
# Make changes
git checkout -b feat-my-feature
# ... make changes ...
git add .
git commit -m "Add new feature"
git push origin feat-my-feature
# Merge PR on GitHub (or force push to main if needed)
```

### Future (With Team)
```bash
# Make changes
git checkout -b feat-my-feature
# ... make changes ...
git add .
git commit -m "feat(module): add new feature"  # Conventional commits
git push origin feat-my-feature
# Create PR on GitHub
# Wait for CI checks
# Request review from code owners
# Merge after approval
```

## Next Steps

1. **Commit these files**:
   ```bash
   git add .github/ SECURITY.md .pre-commit-config.yaml
   git commit -m "Add branch protection artifacts and security policy"
   git push origin feat-serhan
   ```

2. **Merge to main**:
   - Create PR from feat-serhan to main
   - GitHub Actions will run automatically
   - Merge when checks pass

3. **Optional: Enable branch protection**:
   - Follow steps in section 2
   - Start with minimal settings
   - Add more rules as team grows

4. **Deploy infrastructure**:
   ```bash
   cd terraform/environments/dev
   tofu init
   tofu plan
   tofu apply
   ```

## Troubleshooting

**GitHub Actions not running?**
- Ensure Actions are enabled: Settings > Actions > Allow all actions

**Pre-commit hooks too strict?**
- Comment out specific hooks in `.pre-commit-config.yaml`
- Run `pre-commit run --all-files` to test

**Branch protection blocking you?**
- Ensure "Include administrators" is UNCHECKED
- Or add yourself to bypass list

**CODEOWNERS not working?**
- File must be in `.github/CODEOWNERS` (not `CODEOWNERS`)
- Requires "Code Owners" feature (available in all GitHub plans)

## Resources

- [GitHub Branch Protection Rules](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches)
- [Conventional Commits](https://www.conventionalcommits.org/)
- [GitHub Actions Docs](https://docs.github.com/en/actions)
- [CODEOWNERS Syntax](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/about-code-owners)

---

**Remember**: As solo developer, these protections are optional guardrails. Use what helps, skip what doesn't. The infrastructure is ready to scale when you add team members.
