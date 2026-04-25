# Collaboration Rules

Welcome to the **Classroom Emotion Detection System** project! To work efficiently over this 9-day sprint, please follow these rules:

## 1. Picking an Issue
*   Browse the [Project Board](https://github.com/users/4awmy/projects/12).
*   Pick any issue that matches your role (Backend, AI/CV, or Frontend).
*   **Assign yourself** to the issue so others know you are working on it.
*   Move the issue to the **In Progress** column.

## 2. Branching Strategy
*   Create a new branch for every issue.
*   Format: `feature/issue-[number]-[short-description]`
*   Example: `git checkout -b feature/issue-7-fastapi-skeleton`

## 3. Development Workflow
*   **Linting:** Run `ruff check .` before committing to ensure code quality.
*   **Testing:** Ensure all tests pass by running `pytest`.
*   **Commits:** Use descriptive commit messages.

## 4. Protection Rules & Review
*   **Mandatory Review:** All Pull Requests must be reviewed by the **Lead Developer (4awmy)** and **GitHub Copilot** before merging.
*   Direct commits to `main` or `dev` are strictly prohibited.
*   Code must pass all linting checks in the PR pipeline.

## 5. Pull Requests (PRs)
*   Once finished, push your branch and open a PR against the `dev` branch.
*   Reference the issue number in your PR description (e.g., `Closes #7`).
*   The **Backend Lead (4awmy)** acts as the Gatekeeper and will review/merge all PRs.

## 6. Definition of Done
*   Code is functional and meets the issue description.
*   New endpoints are documented or added to the README.
*   Docker container for the service builds and runs successfully.
