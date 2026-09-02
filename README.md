# SmartHome-IDIG4110
Design and partial prototyping of a digital twin of a Smart Home

## Installation

Follow these steps to set up the project locally.

### Prerequisites

Make sure you have the following installed:

* [Git](https://git-scm.com/)
* Required runtime/environment for the project
* Required package manager

### Clone the Repository

```bash
git clone https://github.com/akanksha-00/SmartHome-IDIG4110.git
cd SmartHome-IDIG4110
```

## Contributing

Please follow the development workflow and guidelines below.

### 1. Create an Issue

Before starting work, create or identify an issue describing the bug, feature, or improvement.

For larger changes, discuss the proposed solution with the maintainers before implementation.

### 2. Create a Branch

Always create a new branch from the latest `master` branch.

```bash
git checkout master
git pull origin master
git checkout -b <branch-name>
```

Do not make changes directly on `master`.

### 3. Branch Naming Convention

Use descriptive and consistent branch names.

| Type          | Format                   | Example                       |
| ------------- | ------------------------ | ----------------------------- |
| Feature       | `feature/<description>`  | `feature/user-authentication` |
| Bug fix       | `fix/<description>`      | `fix/login-validation`        |
| Hotfix        | `hotfix/<description>`   | `hotfix/payment-error`        |
| Refactoring   | `refactor/<description>` | `refactor/api-client`         |
| Documentation | `docs/<description>`     | `docs/update-readme`          |
| Testing       | `test/<description>`     | `test/user-service`           |
| Chore         | `chore/<description>`    | `chore/update-dependencies`   |

#### Branch Naming Rules

* Use lowercase letters.
* Use hyphens or underscores consistently; prefer hyphens where possible.
* Keep branch names short and descriptive.
* Avoid spaces.
* Avoid special characters.
* Reference the issue number when applicable.

Example:

```text
feature/123-user-registration
fix/456-invalid-token
docs/789-api-documentation
```

### 4. Make Your Changes

Keep commits focused and related to a single change.

```bash
git status
git add .
git commit -m "feat: add user registration"
```

Write clear and meaningful commit messages.

### 5. Push Your Branch

```bash
git push origin <branch-name>
```

For example:

```bash
git push origin feature/123-user-registration
```

---

## Pull Request Guidelines

GitHub uses the term **Pull Request (PR)**. A PR is used to propose merging changes from your branch into the target branch.

### Create a Pull Request

After pushing your branch:

1. Open the repository on GitHub.
2. Select **Pull requests**.
3. Click **New pull request**.
4. Select your source branch.
5. Select the target branch, `master`.
6. Provide a clear title and description.
7. Link the related issue.
8. Add reviewers if required.
9. Submit the Pull Request.

### Pull Request Requirements

Before creating a PR, make sure:

* [ ] The branch is based on the latest `master`.
* [ ] The code builds successfully.
* [ ] Tests have been added or updated where applicable.
* [ ] All tests pass locally.
* [ ] Code follows the project's coding standards.
* [ ] Documentation has been updated if necessary.
* [ ] No secrets or sensitive information are committed.
* [ ] The PR addresses a single feature, bug fix, or related change.
* [ ] The related issue is referenced.

### Keep Your Branch Updated

If `master` has changed while you are working, update your branch before merging:

```bash
git checkout master
git pull origin master
git checkout <branch-name>
git fetch origin
git rebase origin/master
```

Resolve any conflicts, run the tests again, and push the updated branch:

```bash
git push origin <branch-name>
```

### Pull Request Review

At least one reviewer should review the PR before it is merged, unless the project maintainers specify otherwise.

Reviewers may:

* Approve the PR.
* Request changes.
* Leave comments or suggestions.

Address all required review comments before merging.

### Merging

Only merge a Pull Request when:

* Required reviews are approved.
* CI/CD checks are passing.
* All required discussions are resolved.
* The branch meets the project's contribution requirements.

Preferred merge methods should follow the repository's configured GitHub merge strategy.

---

## Development Workflow

The recommended workflow is:

```text
Issue
  ↓
Create branch
  ↓
Make changes
  ↓
Run tests
  ↓
Commit changes
  ↓
Push branch
  ↓
Create Pull Request
  ↓
Code review
  ↓
Address feedback
  ↓
CI checks
  ↓
Approval
  ↓
Merge into master
```

### Quick Reference

```bash
# Update master
git checkout master
git pull origin master

# Create a branch
git checkout -b feature/<description>

# Make changes and commit
git add .
git commit -m "feat: <description>"

# Push branch
git push -u origin feature/<description>

# After review/approval, merge through GitHub
```

### Coding Practices
* Write clean, readable, and maintainable code.
* Prefer simple and understandable solutions over unnecessary complexity.
* Use meaningful names for variables, functions, classes, files, and modules.
* Avoid duplicate code; reuse existing functionality where appropriate.
* Keep functions and methods small and focused on a single responsibility.
* Remove unused code, imports, variables, and dependencies.
* Do not commit temporary, debug, or experimental code.
* Keep changes focused on the purpose of the branch or issue.

> **Important:** Do not push directly to `master`. All changes should be submitted as a Pull Request unless explicitly authorised by the project maintainers. Please keep commits clean and short, probably one commit per independent change. Make sure to rebase the changes from time to time to avoid large conflict resolution. 
