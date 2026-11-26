# UParReči — publication checklist (2026)

This checklist is not a legal certification. Complete it before opening the site to the public.

## Database and authentication

- [ ] In Supabase SQL Editor, run `supabase/migrations/20261125_profile_grade9_username_cooldown.sql` on the existing project. For a fresh project, run the current `supabase/schema.sql` instead.
- [ ] Confirm the Supabase project URL and publishable/anon key in Vercel environment variables (`VITE_SUPABASE_URL`, `VITE_SUPABASE_ANON_KEY`). Never use a service-role/secret key in browser code.
- [ ] Confirm RLS is enabled on every application table and test as anonymous, ordinary user and admin.
- [ ] In Supabase Auth URL Configuration, set the production Site URL and allow only required production and local redirect URLs.
- [ ] In Google Cloud OAuth client, set the exact Supabase callback URL shown in Supabase Google provider settings as an Authorized redirect URI. Keep the Google client secret only in Supabase.
- [ ] Configure email confirmation, password reset redirects and SMTP sender details.

## Hosting and application checks

- [ ] Vercel project root is `./`, framework is Vite, build command is `npm run build`, output directory is `dist`.
- [ ] Test sign-up, email confirmation, sign-in, Google sign-in, sign-out and password reset on the production domain.
- [ ] Test username changes: initial username selection, successful change, blocked second change before 14 days, and allowed change after 14 days.
- [ ] Test grade 9 in both the editor and search filters; verify the Supabase migration has been applied.
- [ ] Test PDF/image upload limits, file types, deletion, reporting, likes, comments, bookmarks and mobile layouts.
- [ ] Add a real support/contact email and verify that it is monitored.
- [ ] Ensure `.env` is ignored by Git and no service-role key, OAuth secret or other credential is committed.

## Legal, privacy and safeguarding review

- [ ] Replace the draft privacy policy and terms with documents reflecting the actual operator, contact details, purposes, legal bases, retention periods, processors, international transfers, user rights and complaint process.
- [ ] Document the actual use of Supabase, Vercel, Google OAuth, email delivery, analytics and cookies (including any optional trackers).
- [ ] Decide and document the minimum age, parental/guardian consent process where required, and a safe process for requests from minors and guardians.
- [ ] Add a clear copyright complaint/takedown process and a repeat-infringer policy; review user-submitted text and files.
- [ ] Define moderation response times, prohibited content, reporting escalation and account suspension/deletion procedures.
- [ ] Have a qualified legal professional review requirements in Montenegro and, if serving people in the EU, applicable GDPR and consumer/platform rules.

Do not treat the included policy pages as legal advice or proof of compliance. They are starter drafts only.
