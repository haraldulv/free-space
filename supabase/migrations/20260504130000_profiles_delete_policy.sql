-- Tillater at innloggede brukere sletter sin egen profile-rad. Brukes av
-- "Slett konto"-flyten på web (deleteAccountAction) og iOS (SettingsView).
-- Cascader til bookings, listings, favoritter osv. via FK-deklarasjonene.
--
-- NB: auth.users-raden blir IKKE slettet (krever service_role key og admin-API).
-- Vi sletter bare profile + relatert data og signOut'er brukeren — det er
-- tilstrekkelig for App Store-konformitet og webens nåværende oppførsel.

CREATE POLICY IF NOT EXISTS "Users can delete own profile"
ON public.profiles
FOR DELETE
TO authenticated
USING (auth.uid() = id);
