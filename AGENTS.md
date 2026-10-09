# AGENTS.md

Instructions for AI coding agents (Claude Code, Codex, Cursor, and similar) working in this repository. Humans: see `README.md` for the git workflow — this file does not repeat it.

## Project

Digital twin of a smart home, built for IDIG4110 at NTNU. Simulated devices publish over MQTT, a controller runs locally and keeps working when the platform is unreachable, and a FastAPI backend keeps the twin state and serves a dashboard.

It is a university project. **The written report matters more than the code.** Decisions need to be explainable by a human at an oral exam, so prefer the simple solution that can be defended over the clever one that cannot.

## Layout

```
backend/smarthome-api/     FastAPI service (Python 3.14, uv)
  src/smarthome_api/
    api/routes/            HTTP endpoints
    services/              business logic
    repositories/          all data access
    schemas/               Pydantic models for the API
  data/                    JSON fixtures (being replaced by MongoDB)
frontend/                  dashboard
docs/                      architecture, data model, ADRs
```

## Commands

Run from `backend/smarthome-api/`:

```bash
uv sync                      # install dependencies
uv run fastapi dev           # start the API in development
uv run pytest                # run tests
```

## Architecture rules

- **Layering is one-way:** `routes → services → repositories → storage`. Never skip a layer, never call storage from a route.
- **Repositories are the only place storage is touched.** This is deliberate: it is what lets the storage engine change without touching the rest of the backend.
- **API schemas are not database models.** Keep `schemas/` (what the API exposes) separate from database models. They diverge on purpose.
- **The backend never publishes to device MQTT topics.** It publishes to the controller only. The controller is the single gatekeeper for commands reaching devices.
- Safety-critical logic belongs on the controller, not the backend. If a feature must work with no internet, it does not go in FastAPI.

## Data rules

- Every document carries the household/house key, and **every query filters by it**.
- Two timestamps on anything from a device: `observed_at` (device clock) and `received_at` (backend clock). Never fill one in from the other.
- Event, alert and audit collections are **append-only**. Corrections are new records.
- Nothing is hard-deleted. Use a status field and a timestamp.
- Current state and history live in different collections and never merge.
- `request_id` is unique; it is the idempotency mechanism.
- The data model in `docs/` is the source of truth. **Do not invent fields.** If something is missing, say so instead of adding it silently.

## Code style

Match the surrounding code rather than importing another project's conventions. In this backend that currently means: type hints on public functions, small focused functions, section banner comments in long modules, and `None` returned for "not found" rather than raised exceptions.

Remove what you no longer use — dead code, unused imports, commented-out experiments.

## Git

Follow `README.md`. In short: branch from `master`, never commit to `master`, one logical change per commit, conventional prefixes (`feat:`, `fix:`, `docs:`, `chore:`, `test:`, `refactor:`).

**Agents do not commit or push unless explicitly asked in that message.** Leave changes in the working tree and say what you changed.

## Rules for agents

1. **Ask instead of guessing.** If the requirement is ambiguous, stop and ask. A wrong guess costs more than a question.
2. **Do not add dependencies** without asking first. Every dependency is a decision we have to justify.
3. **Do not change the public API shape** — routes, request or response bodies — without asking. The frontend depends on it.
4. **Do not rewrite someone else's module wholesale.** Make the smallest change that solves the problem.
5. **Stay inside the branch's purpose.** Noticed something unrelated? Mention it, don't fix it.
6. **Never commit secrets.** No `.env`, no credentials, no tokens, no real phone numbers. Test data only.
7. **No fabricated data, citations or benchmark numbers.** If a number is estimated, label it as estimated.
8. **Report honestly.** If tests fail or a step was skipped, say so plainly with the output. Do not describe work as done when it is not.
9. **Flag assumptions** you had to make, at the end of your response.

## Testing

- `pytest`, with integration tests running against a disposable test database — never the development database.
- Every repository method that is used gets at least one test.
- A test that needs the network or a real provider account is not a unit test; isolate it or mark it.

## Course requirements that affect how you work

- **AI use is logged.** Significant AI-assisted work is recorded: date, tool, task, what was kept, changed or rejected, and how it was verified. Agents should summarise their change clearly enough that this entry can be written from it.
- **Architectural decisions get an ADR** in `docs/adr/`: context, options considered, decision, consequences. A decision without a recorded rationale cannot be defended at the exam.
- **Requirements, risks and tests are referenced by ID** (`FR-…`, `QA-…`, `REG-…`, `R…`) wherever code implements one. Traceability is assessed.
