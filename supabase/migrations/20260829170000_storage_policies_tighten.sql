-- Storage-hardening (2026-08-29):
--  1) Fjern "list alle filer"-SELECT for anon på public-buckets. Public-buckets
--     serverer filer via URL uansett; SELECT-policy trengs kun for listing.
--     Innloggede beholder SELECT på egen mappe (eksisterende policy).
--  2) Opplasting til listing-images må skje i egen mappe (<auth.uid()>/...),
--     ikke hvor som helst i bucketen.

drop policy if exists "View images folder public users 1i0okip_0" on storage.objects;
drop policy if exists "Public read access 1oj01fe_0" on storage.objects;

drop policy if exists "Give users authenticated access to upload images 1i0okip_0" on storage.objects;
create policy "Users upload listing images to own folder"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'listing-images'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
