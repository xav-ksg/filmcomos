# FilmOS

Film Commission Operating System — piloting at Yosemite Film Commission (YFC),
designed to be white-labeled for global film commissions worldwide.

> **🗺️ Source-of-truth map — READ FIRST (any KSG repo):** `Xav Master Control/KSG Source-of-Truth Index (2026-07-13).md` — every KSG platform's repo, prod, DB, canonical spec, build-state doc, Notion mirror, and which shared standards apply. **This repo = FilmComOS/FilmOS** (`filmcomos`, Next.js 16, Supabase, prod from `main`). Current build-state lives in **git history + the product spec below** — there is no in-repo RESUME doc yet. **FSM (`xav-ksg/frost-shop`) is the KSG reference implementation** — its security patterns already applied here (Watchtower Layer A); its form-guard / Turnstile (flag-gated) / Frosty / email-design patterns are fork-ready when relevant. KSG entities (Ignite Space, Frost Shop, etc.) must appear on par with every other vendor in FilmOS.

> **Family standards:** load the relevant KSG shared standard before building the thing it governs (Platform Harmony, Email Design, Search Everywhere, UI-UX, Compliance Partnership, Two-Way Comms, Scale-Trigger). Exact locations are in the Source-of-Truth Index §3.

## Primary Reference

See the full product specification at:
[./docs/FilmOS_YFC_Product_Spec_v2.docx](./docs/FilmOS_YFC_Product_Spec_v2.docx)
Phase-1 scope + blockers: [./docs/phase-1-scope.md](./docs/phase-1-scope.md) · [./docs/phase-1-blockers.md](./docs/phase-1-blockers.md)

## Tech Stack

- **Framework:** Next.js 16 (App Router)
- **Language:** TypeScript
- **Styling:** Tailwind CSS
- **Database & Auth:** Supabase
- **Hosting:** Vercel
- **AI:** Claude API
- **Mobile:** React Native / Expo

## Ownership

Kenwood Solutions Group (KSG). Founder and operator: Xav Dubois (xav@kenwoodsolutions.com).
