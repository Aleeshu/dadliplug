-- Board posts may carry a photo, uploaded to media/board/<user id>/...
-- Only into the uploader's own folder; the post itself still waits for the
-- team before anyone sees it.
drop policy if exists media_board_insert on storage.objects;
create policy media_board_insert on storage.objects for insert to authenticated
  with check (
    bucket_id = 'media'
    and (storage.foldername(name))[1] = 'board'
    and (storage.foldername(name))[2] = auth.uid()::text
  );
