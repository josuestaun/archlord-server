# Project instructions

## Scope and language

- Act as the project architect and lead developer. Own research, implementation, testing, debugging, and technical documentation within the task the user authorized.
- Communicate with the user in Spanish. Write code, identifiers, code comments, branch names, and commit messages in English.
- Write `AGENTS.md` and technical instructions for agents in English. Write human-facing documentation, including the PR template and files under `docs/`, in Spanish.
- Prioritize a reproducible local setup. See [the roadmap](docs/ROADMAP.md) for milestones and [the architecture](docs/ARCHITECTURE.md) for current decisions and open questions.

## Vibe coding workflow

- Turn product intent into a small, observable outcome. State consequential assumptions, make reasonable reversible decisions, and proceed with safe local work. Ask when a decision materially changes scope or requires permission.
- Inspect the relevant files and Git status before editing. Preserve user changes and keep each diff focused on the outcome.
- Favor the simplest design that satisfies the acceptance criteria. Reuse existing code and tools where they fit. Choose the game-server stack after establishing client and upstream compatibility. Consider TypeScript and Angular when a project-owned tool or web interface has a concrete need.
- Use primary sources for ArchLord claims where available. Record the source and target build when relevant. Label maintainer reports, local observations, assumptions, and open questions accurately.
- Verify changes through their normal entry points. Reproduce failures locally, investigate the cause, and verify fixes. Add tests for new behavior or specific regressions where they improve confidence.
- Record important decisions in `docs/ARCHITECTURE.md` with their status, rationale, and conditions for revisiting them. Update `docs/ROADMAP.md` when milestones or priorities change.
- Finish by reporting the active branch, changes made, checks performed, and any pending verification or decision.

## Git workflow

- Use `main` for stable releases and `develop` for integration. Never develop features directly on either branch. The initial repository baseline on `main` is a one-time bootstrap that requires explicit authorization.
- Start each development task from up-to-date `develop` on a new `feature/<description>` or `fix/<description>` branch. Use lowercase English and hyphens in branch descriptions. Inspect the working tree first and preserve existing user changes.
- Integrate feature and fix branches through pull requests into `develop`. Start urgent `hotfix/<description>` branches from up-to-date `main`, integrate them into `main` through a pull request, and bring the changes back to `develop` through a pull request.
- Create `release/<version>` from up-to-date `develop` when a release needs preparation. Promote a tested release to `main` through a pull request and bring any release changes back to `develop` through a pull request. See [the Git workflow guide](docs/GIT_WORKFLOW.md) for branch origins and destinations.
- Prepare small, single-purpose commits using Conventional Commits in English. Run the relevant checks and review the changes before preparing commits.
- Obtain the user's explicit authorization before committing, pushing, merging, or creating a pull request. Obtain explicit authorization before force pushing or rewriting history. Authorization for one action does not authorize other actions.

## Permissions and project material

- Read-only research using public documentation is in scope when requested. Get explicit approval before external actions such as contacting third parties, fetching or cloning repositories, installing reviewed dependencies, publishing, deploying, or exposing a service beyond the local machine.
- Get explicit approval before destructive actions, including deleting user data or resetting a database.
- Never download proprietary files or unknown dependencies. Use only project-owned or appropriately authorized inputs and verify provenance before use. Keep local binaries, game assets, credentials, database dumps, and debug captures out of Git.
- Use local test accounts and values in configuration examples. Keep services bound to loopback for local development. Check that logs and artifacts omit secrets before sharing them.
