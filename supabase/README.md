# Supabase database setup

This migration defines the PostgreSQL schema, seed data and row-level security policies for AM Educare. It includes profiles and roles, courses, modules, lessons, enrollments, progress, quizzes and attempts, assignments and submissions, certificates, resources, discussions and moderation reports, reviews, bookmarks, live classes, careers, announcements, notifications and AM BioTutor conversation records.

## Apply to a Supabase project

1. Create a Supabase project and install the Supabase CLI.
2. From this project directory, run `supabase login`, `supabase link --project-ref YOUR_PROJECT_REF`, then `supabase db push`.
3. Configure email confirmation and password recovery under Supabase Auth. Keep the service-role key server-side; it must never appear in browser code.
4. Promote the first administrator using the Supabase SQL editor as the project owner:

   ```sql
   update public.profiles set role = 'admin' where id = 'AUTH_USER_UUID';
   ```

5. Create private storage buckets for lesson notes, assignment submissions, and instructor uploads. Add bucket-specific policies that check `auth.uid()` and course enrollment. Do not make assignment uploads public.
6. Test policies using separate student, instructor and administrator accounts before entering real learner data.

The migration seeds the ten AM Educare subject areas, nine microbiology courses, two modules and two conceptual lesson records per course. Course lesson video assets are intentionally unconfigured. The current static preview does not connect its screens to Supabase yet; configure and implement the client/server integration before treating panel data as live.

Quiz question answer keys are not readable to students through table queries. Students retrieve prompts through `get_quiz_questions()` and submit via `submit_quiz_attempt()`, which calculates the score on the database server.

