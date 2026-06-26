-- Harden the M3 functions flagged by the Supabase security advisor.
-- Applied to project avdfneyqqmgzwzrmjtkv via Supabase MCP on 2026-06-13.

-- 1) Pin search_path on the code generator.
alter function public.gen_room_code() set search_path = public;

-- 2) Restrict EXECUTE to signed-in users only (revoke the implicit PUBLIC grant
--    and anon). create_room/join_room already reject anon at runtime; this also
--    silences the anon-executable lint. is_room_member must stay callable by
--    `authenticated` because RLS policies evaluate it as the querying role.
revoke execute on function public.create_room(text, text) from public, anon;
revoke execute on function public.join_room(text)         from public, anon;
revoke execute on function public.is_room_member(uuid)    from public, anon;
revoke execute on function public.gen_room_code()         from public, anon, authenticated;

grant execute on function public.create_room(text, text) to authenticated;
grant execute on function public.join_room(text)        to authenticated;
grant execute on function public.is_room_member(uuid)   to authenticated;
