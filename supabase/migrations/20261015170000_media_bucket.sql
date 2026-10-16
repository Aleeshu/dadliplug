-- Public image bucket for listing photos, ad and event pictures.
--
-- Public read, because these are shown to guests. Writes are the team's only
-- for now (uploads by owners come with Phase 7's photo picker, which needs
-- per-business folders and size limits first).

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('media', 'media', true, 5242880, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update
  set public = true,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists media_team_write on storage.objects;
create policy media_team_write on storage.objects for all
  using (bucket_id = 'media' and public.is_team_admin())
  with check (bucket_id = 'media' and public.is_team_admin());
