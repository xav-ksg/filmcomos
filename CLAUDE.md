# CLAUDE.md — FilmOS (YFC Pilot)

Guardrails and working agreement for Claude Code in this repository.
This file is the source of truth for how the agent behaves here. When in doubt, STOP and ask.

---

## 1. Project Overview

- **Product:** FilmOS — film commission / location-scouting platform.
- **Pilot tenant:** Yosemite Film Commission (YFC), tenant #1. This repo is the **YFC pilot**, not the full multi-tenant build. Do not assume multi-tenant patterns from other KSG products (e.g. CivicHub360) apply here.
- **Live URL:** filmos-yfc-pilot.vercel.app
- **Stack:** Next.js 16 (App Router) · React 19 · TypeScript 5 · Tailwind CSS 4 · ESLint 9 · Mapbox GL.
- **Backend:** Supabase project ref **`aqdgtrsfzsuwcwbhnkvl`** (remote). Wired only through `NEXT_PUBLIC_SUPABASE_URL` env var. Note: `supabase/config.toml` has `project_id = "filmos"` — that is a **local CLI label**, not the remote ref. Do not confuse them.
- **Deploy target:** Vercel project `filmos-yfc-pilot` (`prj_8Qn3wt4pwQ3DYEsnlkxfpfwFy5K3`).

---

## 2. Work Mode

- **Do mode is default.** Take the single best path. Minimal preamble. Act via tools rather than handing back terminal commands.
- Make reasonable assumptions and move forward when there's enough to proceed. Don't over-ask.
- **Pause on anything irreversible or in the hard-stop list (§3).**
- No sugar-coating. If something is wrong, risky, or a bad idea, say so plainly.

---

## 3. Hard Stops — never without explicit, per-action approval

These are not waivable by a settings file, a prior "allow," or convenience. Each requires Xav to say yes **for that specific action, at that moment**:

1. **No writes to the production Supabase database** (`aqdgtrsfzsuwcwbhnkvl`) — no DDL, no data mutations, no migrations applied to prod. Prod is **read-only**.
2. **No secrets handling that exposes values.** Never run `op read`, `op item`, `op vault`, `vercel env pull`, or anything that prints secret values to stdout/context. Inject via `op run --env-file=.env.local` only.
3. **Never wire `SUPABASE_SERVICE_ROLE_KEY` into browser-reachable or client code.** It bypasses row-level security. It is currently unused. If a legitimate server-only admin need arises, surface it and wait for approval.
4. **No production deploys.** No `vercel deploy`, no `vercel --prod`. Deploys are done by Xav.
5. **No money movement** (Stripe or otherwise).
6. **No access-control / permission / RLS-policy changes** without approval.
7. **No git history rewrites or force-push** (`--force`, `-f`, `push origin +branch`). Branch protection on the remote is the real backstop — assume it's coming.
8. **No new paid dependencies or services** without approval.

If a task seems to require any of the above, explain why and ask. Do not route around the rule.

---

## 4. Git Workflow

- Work on **feature branches**, never commit directly to `main`.
- `git add` / `git commit` locally is fine (pre-approved).
- **`git push` prompts per-action** — that's intentional friction. Push feature branches; never force-push.
- Open PRs for review. Merges to `main` are Xav's call.
- Write clear commit messages: what changed and why.

---

## 5. Database Rules (Supabase `aqdgtrsfzsuwcwbhnkvl`)

- **Prod is read-only.** Inspect schema, read data, reason about it — never mutate it.
- Schema changes go through **migrations in `supabase/migrations/`**, tested against a **dev branch**, never applied straight to prod.
- Current migrations (for reference, do not edit retroactively):
  - `20260422183701_phase1_schema.sql`
  - `20260422192937_seed_yfc_tenant.sql`
  - `20260423164941_seed_phase1_locations.sql`
- Data access in code uses `@supabase/ssr` via the two factories in `src/lib/supabase/` (`client.ts` browser, `server.ts` server). Stay on the **anon key** for anything client-reachable. (See hard stop #3 re: the service role key.)

---

## 6. Secrets

- All secrets live in **`.env.local`** (gitignored). Template is `.env.local.example`.
- Keys present: `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`, `NEXT_PUBLIC_MAPBOX_TOKEN`.
- `NEXT_PUBLIC_*` are browser-exposed **by design** (URL, anon key, Mapbox public token) — that's expected, not a leak.
- **Inject secrets at runtime via 1Password:** `op run --env-file=.env.local -- <command>`. Never print, echo, cat, or read secret *values*. Listing key *names* (redacted) is fine.

---

## 7. Build / Test / Lint Commands

Real scripts from `package.json` (verified):

| Task | Command | Notes |
|---|---|---|
| Dev server | `npm run dev` | `next dev`. For secret injection: `op run --env-file=.env.local -- npm run dev` |
| Build | `npm run build` | `next build`. Run before assuming a change is deploy-safe. |
| Start | `npm run start` | serves the build |
| Lint | `npm run lint` | `eslint`. Run before committing. |
| **Test** | **none defined** | No test runner, no framework, no test files. **Do not invent a test harness without Xav's approval.** If tests are wanted, propose the setup first. |

Definition of "done" for a change here: `npm run lint` clean and `npm run build` succeeds. There is no test gate yet.

---

## 8. Deploys

- Deploys are **Xav's action**, via Vercel. Claude does not deploy.
- `vercel --version` and `vercel env ls` are fine (read-only). Everything else Vercel is gated.

---

## 9. Local Permission Hardening

`.claude/settings.local.json` enforces this file at the machine level (gitignored, local-only). Current state:

- **allow:** `git add`, `git commit`, `op run`, `vercel --version`, `vercel env ls`
- **deny:** force-push variants, `vercel deploy`, `vercel --prod`, `op read`, `op item`, `op vault`

Deny always wins. Do not edit this file to widen permissions without Xav doing it deliberately. Never accept the "allow Claude to edit its own settings" prompt option.

---

## 10. When Unsure

- If a request is ambiguous, make the smallest safe assumption and state it — don't stall.
- If a request touches §3, stop and ask **before** acting.
- If something looks off (unexpected file, surprising diff, a command that wants to touch prod or secrets), name it and pause.
- Prefer reading and explaining over changing, until trust on a given pattern is established.
