# Creating & Auditing AGENTS.md

## Creating a New AGENTS.md

1. **Discover the repo's default branch:**

   ```bash
   git symbolic-ref --short refs/remotes/origin/HEAD | sed 's#^origin/##'
   ```

2. **Discover deploy destinations:**

   ```bash
   ls config/deploy.*.yml | sed 's/.*deploy\.\(.*\)\.yml/\1/'
   # Fizzy: ls saas/config/deploy.*.yml | ...
   ```

3. **Check for pre-deploy steps** (e.g., `bin/rails saas:enable` for Fizzy).

4. **Read existing README.md and bin/setup** for test commands and setup steps.

5. **Write the AGENTS.md** following the template in spec.md.

## Auditing an Existing AGENTS.md

1. Run `bin/verify-app-registry` (in the coworker repo) to check branch and
   destination drift.

2. Verify MUST sections are present and accurate:
   - Deploy section has correct branch, command, and destinations
   - Commands section has test and setup commands

3. Check for anti-patterns (see spec.md).
