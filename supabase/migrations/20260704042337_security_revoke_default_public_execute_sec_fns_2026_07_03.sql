-- Trigger function needs no caller EXECUTE; revoke the default PUBLIC grant.
-- sec_is_blocked intentionally stays anon/authenticated-callable (read-only probe).
-- Applied to FilmComOS prod 2026-07-03 via MCP (ledger 20260704042337). Companion
-- to the FSM fix — the other sec_* revokes were already in the defense-core migration.
revoke execute on function public.sec_guard_public_insert() from public, anon, authenticated;
