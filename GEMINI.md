# Classroom Emotion System

## Project Conventions

1. **Collaboration Protocol**: Use the `gh` CLI to create branches, commits, and PRs for every implementation.
2. **No Unsolicited Work**: Do NOT start any new task or sub-task without first asking for user permission.
3. **PR & Merge Workflow**:
    1. Create a Draft PR for every task.
    2. Invoke the `code_reviewer` agent to audit the PR.
    3. Wait for explicit user approval before merging.
4. **Stuck/Blocked Protocol**: If stuck, comment on the PR tagging the relevant student Lead (e.g., @4awmy for S3) and explain the blocker.
5. **Plan Validation**: Stop work immediately and comment if an error is found in `ARCHITECTURE.md` or `CLAUDE.md`.
6. **Data Isolation**: R/Shiny must never connect to SQLite directly; it only reads nightly CSV exports.
7. **Tech Stack**:
    - **Backend**: Python 3.11
    - **Mobile**: React Native (Expo)
    - **Web**: R/Shiny
8. **Workspace**: Prioritize `C:\Users\omarh\OneDrive\Desktop\Uni` for university-related files.
9. **AGENT VS. COPILOT DEBATE**: 
   - After completing a task and creating a PR, the agent must first perform a self-review of the code.
   - The agent must then tag @Copilot in the PR comments to request a review.
   - Once Copilot provides feedback, the agent MUST debate Copilot's arguments in the PR comments, defending correct patterns or acknowledging valid fixes.
   - The agent must treat Copilot as potentially wrong and prioritize project-specific architecture over generic suggestions.
   - Merging is ONLY allowed after this debate is resolved and the user gives a final 'Merge' command.
10. **AUTOMATIC BRANCH CLEANUP**: 
    - Every 'gh pr merge' command must include the '--delete-branch' flag.
    - This ensures that feature branches are deleted on both GitHub and the local environment immediately upon a successful merge.
    - This rule applies to all future merges without exception.
