# AM Educare

**Learn Microbiology. Understand Life. Shape the Future.**

AM Educare is a microbiology education portal built with plain HTML, CSS and JavaScript. It replaces the previous portfolio homepage with a responsive learning experience, separate Student and Admin panel interfaces, and an initial Supabase/PostgreSQL schema. The current static website does not yet connect to the database.

## Run locally

Open `index.html` in a modern browser, or serve this directory with any static web server. For example, from the project directory:

```sh
python -m http.server 8000
```

Then open `http://localhost:8000`.

## Included in the preview

- Responsive home, course catalogue, course detail and lesson views.
- Search and subject/level filters for microbiology courses.
- Local demo enrollment, lesson completion, saved courses and profile edits.
- Student dashboard with course progress and learning activity visuals.
- Dedicated Admin studio with navigation for overview, student records, courses, instructors, academic operations, site content and analytics.
- Interactive, automatically scored microbiology knowledge check with explanations.
- Study library, sample career listings, instructor directory and FAQ.
- Browser-local discussion creation and course catalogue management screens.
- Demo registration and sign-in forms that create a local browser profile.
- Privacy, educational terms, contact and administration preview pages.
- Form validation, mobile navigation, empty states and accessible status announcements.

Demo learner data is stored in browser `localStorage`. It stays in that browser and is not synchronized or backed up. The course videos, file downloads, account verification, account recovery, third-party login, real community moderation, messaging, and database persistence are not connected. Administration screens are a product preview and are not access-controlled. Listings and instructor profiles are illustrative. Do not use this preview to collect real student information or represent service integrations as active.

## Database setup

The initial database schema, demo course catalog, row-level security policies and protected quiz scoring functions are in [`supabase/migrations/001_initial_schema.sql`](supabase/migrations/001_initial_schema.sql). Apply and configure it using [`supabase/README.md`](supabase/README.md). The website screens are still preview-backed; wire them to Supabase before treating panel data as live.

## Production implementation still needed

This static site is not a production LMS backend. Before launch, implement and configure server-side services for:

- Database backups, policy tests and production data retention.
- Supabase Auth or equivalent secure email, verification, recovery and OAuth flows.
- Server-authorized student, instructor and administrator roles and protected operations.
- Validated APIs for course content, enrollments, durable progress, quizzes, assignments, reviews, discussions and notifications.
- Private, licensed file storage, safe upload validation and managed video hosting.
- Certificate issuance and public verification backed by durable records.
- Instructor moderation and administrator audit logging.
- Secure server-side AI integration with safety controls and rate limits.
- Contact delivery, privacy-conscious analytics, monitoring and deployment secrets.
- Automated security, accessibility and critical student/instructor/admin workflow checks.

Do not put provider secrets in browser JavaScript. Configure and test each provider before describing it as integrated.

