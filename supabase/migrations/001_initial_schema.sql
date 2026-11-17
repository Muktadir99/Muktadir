-- AM Educare · PostgreSQL/Supabase initial schema
-- Apply with: supabase db push  (after linking a Supabase project)
create extension if not exists pgcrypto;

create type public.app_role as enum ('student','instructor','admin');
create type public.course_level as enum ('beginner','intermediate','advanced');
create type public.publish_state as enum ('draft','published','archived');
create type public.question_kind as enum ('single_choice','multiple_choice','true_false','fill_blank','short_answer');
create type public.submission_state as enum ('submitted','reviewed','returned');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null check (char_length(display_name) between 2 and 100),
  avatar_path text,
  bio text check (char_length(coalesce(bio,'')) <= 1200),
  role public.app_role not null default 'student',
  email_verified_at timestamptz,
  suspended_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index profiles_role_idx on public.profiles(role);

create table public.instructor_profiles (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  qualifications text not null default '',
  specialization text not null default '',
  experience_years integer not null default 0 check (experience_years between 0 and 80),
  verified_at timestamptz,
  biography text not null default ''
);

create table public.course_categories (
  id uuid primary key default gen_random_uuid(),
  name text not null unique check (char_length(name) between 2 and 100),
  slug text not null unique,
  description text not null default '',
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);

create table public.courses (
  id uuid primary key default gen_random_uuid(),
  category_id uuid not null references public.course_categories(id) on delete restrict,
  instructor_id uuid references public.profiles(id) on delete set null,
  title text not null check (char_length(title) between 3 and 180),
  slug text not null unique,
  summary text not null default '',
  description text not null default '',
  level public.course_level not null default 'beginner',
  estimated_minutes integer not null default 60 check (estimated_minutes > 0),
  thumbnail_path text,
  learning_objectives jsonb not null default '[]'::jsonb,
  references_text jsonb not null default '[]'::jsonb,
  status public.publish_state not null default 'draft',
  published_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index courses_category_status_idx on public.courses(category_id,status);
create index courses_instructor_idx on public.courses(instructor_id);
create index courses_published_idx on public.courses(published_at desc) where status='published';

create table public.course_modules (
  id uuid primary key default gen_random_uuid(),
  course_id uuid not null references public.courses(id) on delete cascade,
  title text not null check (char_length(title) between 2 and 180),
  description text not null default '',
  sort_order integer not null default 0,
  unique(course_id,sort_order)
);
create index course_modules_course_idx on public.course_modules(course_id,sort_order);

create table public.lessons (
  id uuid primary key default gen_random_uuid(),
  module_id uuid not null references public.course_modules(id) on delete cascade,
  title text not null check (char_length(title) between 2 and 180),
  summary text not null default '',
  video_provider text,
  video_asset_id text,
  duration_seconds integer not null default 0 check (duration_seconds >= 0),
  captions_path text,
  notes_path text,
  sort_order integer not null default 0,
  is_preview boolean not null default false,
  created_at timestamptz not null default now(),
  unique(module_id,sort_order)
);
create index lessons_module_idx on public.lessons(module_id,sort_order);

create table public.enrollments (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references public.profiles(id) on delete cascade,
  course_id uuid not null references public.courses(id) on delete cascade,
  enrolled_at timestamptz not null default now(),
  completed_at timestamptz,
  unique(student_id,course_id)
);
create index enrollments_student_idx on public.enrollments(student_id,enrolled_at desc);
create index enrollments_course_idx on public.enrollments(course_id);

create table public.lesson_progress (
  student_id uuid not null references public.profiles(id) on delete cascade,
  lesson_id uuid not null references public.lessons(id) on delete cascade,
  last_position_seconds integer not null default 0 check (last_position_seconds >= 0),
  completed_at timestamptz,
  updated_at timestamptz not null default now(),
  primary key(student_id,lesson_id)
);

create table public.quizzes (
  id uuid primary key default gen_random_uuid(),
  course_id uuid references public.courses(id) on delete cascade,
  module_id uuid references public.course_modules(id) on delete cascade,
  title text not null,
  time_limit_seconds integer check (time_limit_seconds is null or time_limit_seconds > 0),
  passing_percent integer not null default 60 check (passing_percent between 0 and 100),
  randomize_questions boolean not null default false,
  status public.publish_state not null default 'draft',
  created_by uuid references public.profiles(id) on delete set null,
  check (course_id is not null or module_id is not null)
);
create index quizzes_course_idx on public.quizzes(course_id);

create table public.questions (
  id uuid primary key default gen_random_uuid(),
  quiz_id uuid not null references public.quizzes(id) on delete cascade,
  kind public.question_kind not null,
  prompt text not null,
  options jsonb not null default '[]'::jsonb,
  answer_key jsonb not null default '{}'::jsonb,
  explanation text not null default '',
  points numeric(6,2) not null default 1 check (points > 0),
  sort_order integer not null default 0,
  unique(quiz_id,sort_order)
);
create index questions_quiz_idx on public.questions(quiz_id,sort_order);

create table public.quiz_attempts (
  id uuid primary key default gen_random_uuid(),
  quiz_id uuid not null references public.quizzes(id) on delete cascade,
  student_id uuid not null references public.profiles(id) on delete cascade,
  answers jsonb not null default '{}'::jsonb,
  score_percent numeric(5,2) check (score_percent between 0 and 100),
  started_at timestamptz not null default now(),
  submitted_at timestamptz,
  graded_at timestamptz
);
create index quiz_attempts_student_idx on public.quiz_attempts(student_id,started_at desc);

create table public.assignments (
  id uuid primary key default gen_random_uuid(),
  course_id uuid not null references public.courses(id) on delete cascade,
  title text not null,
  instructions text not null,
  due_at timestamptz,
  max_points numeric(7,2) not null default 100 check (max_points > 0),
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now()
);
create index assignments_course_idx on public.assignments(course_id,due_at);

create table public.submissions (
  id uuid primary key default gen_random_uuid(),
  assignment_id uuid not null references public.assignments(id) on delete cascade,
  student_id uuid not null references public.profiles(id) on delete cascade,
  file_path text not null,
  state public.submission_state not null default 'submitted',
  grade numeric(7,2) check (grade is null or grade >= 0),
  feedback text,
  submitted_at timestamptz not null default now(),
  reviewed_at timestamptz,
  reviewed_by uuid references public.profiles(id) on delete set null,
  unique(assignment_id,student_id)
);
create index submissions_review_idx on public.submissions(state,submitted_at);

create table public.certificates (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references public.profiles(id) on delete cascade,
  course_id uuid not null references public.courses(id) on delete restrict,
  certificate_code text not null unique default encode(gen_random_bytes(12),'hex'),
  issued_at timestamptz not null default now(),
  unique(student_id,course_id)
);

create table public.resources (
  id uuid primary key default gen_random_uuid(),
  category_id uuid references public.course_categories(id) on delete set null,
  title text not null,
  description text not null default '',
  resource_type text not null,
  difficulty public.course_level,
  storage_path text,
  external_url text,
  license_note text not null default '',
  status public.publish_state not null default 'draft',
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  check (storage_path is not null or external_url is not null)
);
create index resources_discovery_idx on public.resources(status,category_id,resource_type);

create table public.discussions (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references public.profiles(id) on delete cascade,
  course_id uuid references public.courses(id) on delete set null,
  title text not null check (char_length(title) between 8 and 200),
  body text not null check (char_length(body) between 10 and 8000),
  is_hidden boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index discussions_recent_idx on public.discussions(created_at desc) where not is_hidden;

create table public.discussion_comments (
  id uuid primary key default gen_random_uuid(),
  discussion_id uuid not null references public.discussions(id) on delete cascade,
  author_id uuid not null references public.profiles(id) on delete cascade,
  parent_id uuid references public.discussion_comments(id) on delete cascade,
  body text not null check (char_length(body) between 2 and 4000),
  is_hidden boolean not null default false,
  created_at timestamptz not null default now()
);
create index discussion_comments_thread_idx on public.discussion_comments(discussion_id,created_at);

create table public.reviews (
  id uuid primary key default gen_random_uuid(),
  course_id uuid not null references public.courses(id) on delete cascade,
  student_id uuid not null references public.profiles(id) on delete cascade,
  rating smallint not null check (rating between 1 and 5),
  body text not null default '' check (char_length(body) <= 2000),
  is_visible boolean not null default true,
  created_at timestamptz not null default now(),
  unique(course_id,student_id)
);
create index reviews_course_idx on public.reviews(course_id,is_visible);

create table public.bookmarks (
  student_id uuid not null references public.profiles(id) on delete cascade,
  course_id uuid not null references public.courses(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key(student_id,course_id)
);

create table public.live_classes (
  id uuid primary key default gen_random_uuid(),
  course_id uuid references public.courses(id) on delete set null,
  instructor_id uuid not null references public.profiles(id) on delete cascade,
  title text not null,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  meeting_provider text,
  meeting_ref text,
  recording_path text,
  created_at timestamptz not null default now(),
  check (ends_at > starts_at)
);
create index live_classes_schedule_idx on public.live_classes(starts_at);

create table public.class_attendance (
  live_class_id uuid not null references public.live_classes(id) on delete cascade,
  student_id uuid not null references public.profiles(id) on delete cascade,
  joined_at timestamptz,
  attended_minutes integer not null default 0 check (attended_minutes >= 0),
  primary key(live_class_id,student_id)
);

create table public.career_opportunities (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  organization text not null,
  location text not null default '',
  eligibility text not null default '',
  qualifications text not null default '',
  deadline date,
  application_url text,
  opportunity_type text not null,
  status public.publish_state not null default 'draft',
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now()
);
create index career_active_idx on public.career_opportunities(deadline) where status='published';

create table public.announcements (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  body text not null,
  audience public.app_role[] not null default '{student,instructor}'::public.app_role[],
  published_at timestamptz,
  expires_at timestamptz,
  created_by uuid references public.profiles(id) on delete set null
);

create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  title text not null,
  body text not null,
  read_at timestamptz,
  created_at timestamptz not null default now()
);
create index notifications_unread_idx on public.notifications(user_id,created_at desc) where read_at is null;

create table public.ai_conversations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  title text not null default 'Microbiology study session',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table public.ai_messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.ai_conversations(id) on delete cascade,
  role text not null check (role in ('user','assistant')),
  content text not null check (char_length(content) <= 12000),
  created_at timestamptz not null default now()
);
create index ai_messages_conversation_idx on public.ai_messages(conversation_id,created_at);

create table public.content_reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references public.profiles(id) on delete cascade,
  discussion_id uuid references public.discussions(id) on delete cascade,
  comment_id uuid references public.discussion_comments(id) on delete cascade,
  reason text not null check (char_length(reason) between 5 and 1000),
  resolved_at timestamptz,
  resolved_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  check (num_nonnulls(discussion_id,comment_id)=1)
);

-- New accounts receive a student profile. Role changes must go through an admin service.
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  insert into public.profiles(id,display_name,email_verified_at)
  values(new.id,coalesce(nullif(new.raw_user_meta_data->>'name',''),split_part(new.email,'@',1)),new.email_confirmed_at);
  return new;
end; $$;
create trigger on_auth_user_created after insert on auth.users
for each row execute function public.handle_new_user();

create or replace function public.current_role()
returns public.app_role language sql stable security definer set search_path=public as $$
  select role from public.profiles where id=auth.uid() and suspended_at is null
$$;
create or replace function public.has_role(required public.app_role)
returns boolean language sql stable security definer set search_path=public as $$
  select coalesce(public.current_role()=required or public.current_role()='admin',false)
$$;

-- Prevent self-service role escalation and account suspension edits.
create or replace function public.protect_profile_privileges()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  if auth.uid() is not null and auth.uid()=old.id and not public.has_role('admin') then
    if new.role is distinct from old.role or new.suspended_at is distinct from old.suspended_at then
      raise exception 'Only an administrator can change account permissions';
    end if;
  end if;
  new.updated_at=now();
  return new;
end; $$;
create trigger protect_profile_privileges before update on public.profiles
for each row execute function public.protect_profile_privileges();

-- RLS is enabled everywhere. Policies are deliberately explicit by ownership/role.
do $$ declare t text; begin
  foreach t in array array['profiles','instructor_profiles','course_categories','courses','course_modules','lessons','enrollments','lesson_progress','quizzes','questions','quiz_attempts','assignments','submissions','certificates','resources','discussions','discussion_comments','reviews','bookmarks','live_classes','class_attendance','career_opportunities','announcements','notifications','ai_conversations','ai_messages','content_reports'] loop
    execute format('alter table public.%I enable row level security',t);
  end loop;
end $$;

create policy profiles_read on public.profiles for select to authenticated using (id=auth.uid() or public.has_role('admin'));
create policy profiles_update_self on public.profiles for update to authenticated using(id=auth.uid() or public.has_role('admin')) with check(id=auth.uid() or public.has_role('admin'));
create policy instructor_profiles_read on public.instructor_profiles for select to anon,authenticated using(verified_at is not null or user_id=auth.uid() or public.has_role('admin'));
create policy instructor_profiles_manage on public.instructor_profiles for all to authenticated using(public.has_role('admin') or user_id=auth.uid()) with check(public.has_role('admin') or user_id=auth.uid());

create policy categories_public_read on public.course_categories for select to anon,authenticated using(true);
create policy categories_admin_manage on public.course_categories for all to authenticated using(public.has_role('admin')) with check(public.has_role('admin'));
create policy courses_public_read on public.courses for select to anon,authenticated using(status='published' or instructor_id=auth.uid() or public.has_role('admin'));
create policy courses_staff_manage on public.courses for all to authenticated using(public.has_role('admin') or (public.has_role('instructor') and instructor_id=auth.uid())) with check(public.has_role('admin') or (public.has_role('instructor') and instructor_id=auth.uid()));
create policy modules_public_read on public.course_modules for select to anon,authenticated using(exists(select 1 from public.courses c where c.id=course_id and (c.status='published' or c.instructor_id=auth.uid() or public.has_role('admin'))));
create policy modules_staff_manage on public.course_modules for all to authenticated using(public.has_role('admin') or (public.has_role('instructor') and exists(select 1 from public.courses c where c.id=course_id and c.instructor_id=auth.uid()))) with check(public.has_role('admin') or (public.has_role('instructor') and exists(select 1 from public.courses c where c.id=course_id and c.instructor_id=auth.uid())));
create policy lessons_public_read on public.lessons for select to anon,authenticated using(is_preview or exists(select 1 from public.course_modules m join public.courses c on c.id=m.course_id where m.id=module_id and (c.status='published' or c.instructor_id=auth.uid() or public.has_role('admin'))));
create policy lessons_staff_manage on public.lessons for all to authenticated using(public.has_role('admin') or (public.has_role('instructor') and exists(select 1 from public.course_modules m join public.courses c on c.id=m.course_id where m.id=module_id and c.instructor_id=auth.uid()))) with check(public.has_role('admin') or (public.has_role('instructor') and exists(select 1 from public.course_modules m join public.courses c on c.id=m.course_id where m.id=module_id and c.instructor_id=auth.uid())));

create policy enrollment_read_own on public.enrollments for select to authenticated using(student_id=auth.uid() or public.has_role('admin') or exists(select 1 from public.courses c where c.id=course_id and c.instructor_id=auth.uid()));
create policy enrollment_insert_self on public.enrollments for insert to authenticated with check(student_id=auth.uid() and public.current_role()='student' and exists(select 1 from public.courses c where c.id=course_id and c.status='published'));
create policy progress_read_own on public.lesson_progress for select to authenticated using(student_id=auth.uid() or public.has_role('admin'));
create policy progress_write_own on public.lesson_progress for all to authenticated using(student_id=auth.uid()) with check(student_id=auth.uid() and exists(select 1 from public.lessons l join public.course_modules m on m.id=l.module_id join public.enrollments e on e.course_id=m.course_id where l.id=lesson_progress.lesson_id and e.student_id=auth.uid()));

create policy quizzes_public_read on public.quizzes for select to authenticated using(status='published' or public.has_role('admin') or exists(select 1 from public.courses c where c.id=course_id and c.instructor_id=auth.uid()));
create policy quizzes_staff_manage on public.quizzes for all to authenticated using(public.has_role('admin') or (public.has_role('instructor') and exists(select 1 from public.courses c where c.id=course_id and c.instructor_id=auth.uid()))) with check(public.has_role('admin') or (public.has_role('instructor') and exists(select 1 from public.courses c where c.id=course_id and c.instructor_id=auth.uid())));
-- Question answer keys are private. Students fetch prompts and submit answers through the RPCs below.
create policy questions_staff_manage on public.questions for all to authenticated using(public.has_role('admin') or exists(select 1 from public.quizzes q join public.courses c on c.id=q.course_id where q.id=quiz_id and c.instructor_id=auth.uid())) with check(public.has_role('admin') or exists(select 1 from public.quizzes q join public.courses c on c.id=q.course_id where q.id=quiz_id and c.instructor_id=auth.uid()));
create policy quiz_attempts_read_own on public.quiz_attempts for select to authenticated using(student_id=auth.uid() or public.has_role('admin'));
revoke insert,update,delete on public.quiz_attempts from authenticated;

create or replace function public.get_quiz_questions(p_quiz_id uuid)
returns table(question_id uuid,kind public.question_kind,prompt text,options jsonb,points numeric,sort_order integer)
language plpgsql stable security definer set search_path=public as $$
begin
  if auth.uid() is null or not exists(select 1 from public.quizzes q where q.id=p_quiz_id and q.status='published') then
    raise exception 'Quiz is unavailable';
  end if;
  return query select qn.id,qn.kind,qn.prompt,qn.options,qn.points,qn.sort_order
    from public.questions qn where qn.quiz_id=p_quiz_id order by qn.sort_order;
end; $$;
grant execute on function public.get_quiz_questions(uuid) to authenticated;

create or replace function public.submit_quiz_attempt(p_quiz_id uuid,p_answers jsonb)
returns jsonb language plpgsql security definer set search_path=public as $$
declare total numeric; earned numeric; result_id uuid; result_items jsonb;
begin
  if auth.uid() is null or public.current_role()<>'student' then raise exception 'Student sign-in required'; end if;
  if not exists(select 1 from public.quizzes q where q.id=p_quiz_id and q.status='published') then raise exception 'Quiz is unavailable'; end if;
  select coalesce(sum(points),0),coalesce(sum(case when p_answers->id::text=answer_key then points else 0 end),0),
    coalesce(jsonb_agg(jsonb_build_object('question_id',id,'correct',p_answers->id::text=answer_key,'explanation',explanation) order by sort_order),'[]'::jsonb)
  into total,earned,result_items from public.questions where quiz_id=p_quiz_id;
  if total=0 then raise exception 'Quiz has no questions'; end if;
  insert into public.quiz_attempts(quiz_id,student_id,answers,score_percent,submitted_at,graded_at)
  values(p_quiz_id,auth.uid(),coalesce(p_answers,'{}'::jsonb),round(earned/total*100,2),now(),now()) returning id into result_id;
  return jsonb_build_object('attempt_id',result_id,'score_percent',round(earned/total*100,2),'passed',round(earned/total*100,2)>=(select passing_percent from public.quizzes where id=p_quiz_id),'feedback',result_items);
end; $$;
grant execute on function public.submit_quiz_attempt(uuid,jsonb) to authenticated;

create policy assignments_read on public.assignments for select to authenticated using(exists(select 1 from public.enrollments e where e.course_id=assignments.course_id and e.student_id=auth.uid()) or public.has_role('admin') or exists(select 1 from public.courses c where c.id=assignments.course_id and c.instructor_id=auth.uid()));
create policy assignments_staff_manage on public.assignments for all to authenticated using(public.has_role('admin') or exists(select 1 from public.courses c where c.id=course_id and c.instructor_id=auth.uid())) with check(public.has_role('admin') or exists(select 1 from public.courses c where c.id=course_id and c.instructor_id=auth.uid()));
create policy submissions_read on public.submissions for select to authenticated using(student_id=auth.uid() or public.has_role('admin') or exists(select 1 from public.assignments a join public.courses c on c.id=a.course_id where a.id=assignment_id and c.instructor_id=auth.uid()));
create policy submissions_student_manage on public.submissions for insert to authenticated with check(student_id=auth.uid() and exists(select 1 from public.assignments a join public.enrollments e on e.course_id=a.course_id where a.id=assignment_id and e.student_id=auth.uid()));
create policy submissions_staff_grade on public.submissions for update to authenticated using(public.has_role('admin') or exists(select 1 from public.assignments a join public.courses c on c.id=a.course_id where a.id=assignment_id and c.instructor_id=auth.uid())) with check(public.has_role('admin') or exists(select 1 from public.assignments a join public.courses c on c.id=a.course_id where a.id=assignment_id and c.instructor_id=auth.uid()));
create policy certificates_public_verify on public.certificates for select to anon,authenticated using(true);
create policy certificates_admin_issue on public.certificates for insert to authenticated with check(public.has_role('admin') or (student_id=auth.uid() and exists(select 1 from public.enrollments e where e.course_id=certificates.course_id and e.student_id=auth.uid() and e.completed_at is not null)));

create policy resources_public_read on public.resources for select to anon,authenticated using(status='published' or public.has_role('admin') or created_by=auth.uid());
create policy resources_staff_manage on public.resources for all to authenticated using(public.has_role('admin') or (public.has_role('instructor') and created_by=auth.uid())) with check(public.has_role('admin') or (public.has_role('instructor') and created_by=auth.uid()));
create policy discussions_public_read on public.discussions for select to anon,authenticated using(not is_hidden or public.has_role('admin') or author_id=auth.uid());
create policy discussions_create on public.discussions for insert to authenticated with check(author_id=auth.uid() and public.current_role()='student');
create policy discussions_owner_moderate on public.discussions for update to authenticated using(author_id=auth.uid() or public.has_role('instructor') or public.has_role('admin')) with check(author_id=auth.uid() or public.has_role('instructor') or public.has_role('admin'));
create policy comments_public_read on public.discussion_comments for select to anon,authenticated using(not is_hidden or public.has_role('admin') or author_id=auth.uid());
create policy comments_create on public.discussion_comments for insert to authenticated with check(author_id=auth.uid());
create policy comments_moderate on public.discussion_comments for update to authenticated using(author_id=auth.uid() or public.has_role('instructor') or public.has_role('admin')) with check(author_id=auth.uid() or public.has_role('instructor') or public.has_role('admin'));
create policy reviews_public_read on public.reviews for select to anon,authenticated using(is_visible or student_id=auth.uid() or public.has_role('admin'));
create policy reviews_enrolled_create on public.reviews for insert to authenticated with check(student_id=auth.uid() and exists(select 1 from public.enrollments e where e.course_id=reviews.course_id and e.student_id=auth.uid()));
create policy reviews_owner_update on public.reviews for update to authenticated using(student_id=auth.uid() or public.has_role('admin')) with check(student_id=auth.uid() or public.has_role('admin'));
create policy bookmarks_owner on public.bookmarks for all to authenticated using(student_id=auth.uid()) with check(student_id=auth.uid());

create policy live_classes_read on public.live_classes for select to authenticated using(public.has_role('admin') or instructor_id=auth.uid() or exists(select 1 from public.enrollments e where e.course_id=live_classes.course_id and e.student_id=auth.uid()));
create policy live_classes_staff_manage on public.live_classes for all to authenticated using(public.has_role('admin') or instructor_id=auth.uid()) with check(public.has_role('admin') or instructor_id=auth.uid());
create policy attendance_read on public.class_attendance for select to authenticated using(student_id=auth.uid() or public.has_role('admin') or exists(select 1 from public.live_classes l where l.id=live_class_id and l.instructor_id=auth.uid()));
create policy attendance_student_write on public.class_attendance for insert to authenticated with check(student_id=auth.uid());
create policy careers_public_read on public.career_opportunities for select to anon,authenticated using(status='published' and (deadline is null or deadline>=current_date) or public.has_role('admin'));
create policy careers_admin_manage on public.career_opportunities for all to authenticated using(public.has_role('admin')) with check(public.has_role('admin'));
create policy announcements_read on public.announcements for select to authenticated using(published_at is not null and published_at<=now() and (expires_at is null or expires_at>now()) and (public.current_role()=any(audience) or public.has_role('admin')));
create policy announcements_admin_manage on public.announcements for all to authenticated using(public.has_role('admin')) with check(public.has_role('admin'));
create policy notifications_owner on public.notifications for select to authenticated using(user_id=auth.uid());
create policy notifications_read_update on public.notifications for update to authenticated using(user_id=auth.uid()) with check(user_id=auth.uid());
create policy ai_conversations_owner on public.ai_conversations for all to authenticated using(user_id=auth.uid()) with check(user_id=auth.uid());
create policy ai_messages_owner on public.ai_messages for all to authenticated using(exists(select 1 from public.ai_conversations c where c.id=conversation_id and c.user_id=auth.uid())) with check(exists(select 1 from public.ai_conversations c where c.id=conversation_id and c.user_id=auth.uid()));
create policy reports_create on public.content_reports for insert to authenticated with check(reporter_id=auth.uid());
create policy reports_admin_read on public.content_reports for select to authenticated using(public.has_role('admin'));
create policy reports_admin_update on public.content_reports for update to authenticated using(public.has_role('admin')) with check(public.has_role('admin'));

-- Seed course categories only. Admin-managed course content should be curated before publication.
insert into public.course_categories(name,slug,sort_order) values
 ('General Microbiology','general-microbiology',1),('Cell Biology and Microbial Structure','cell-biology',2),
 ('Microbial Physiology and Metabolism','microbial-physiology',3),('Medical Microbiology','medical-microbiology',4),
 ('Immunology','immunology',5),('Molecular Biology and Genetics','molecular-biology-genetics',6),
 ('Industrial Microbiology','industrial-microbiology',7),('Environmental Microbiology','environmental-microbiology',8),
 ('Biotechnology and Bioinformatics','biotechnology-bioinformatics',9),('Microbiology Laboratory Techniques','laboratory-techniques',10)
on conflict(slug) do nothing;

insert into public.courses(category_id,title,slug,summary,level,estimated_minutes,learning_objectives,status,published_at)
select c.id,v.title,v.slug,v.summary,v.level,v.duration,v.objectives,'published',now()
from (values
 ('cell-biology','Inside the Microbial Cell','inside-the-microbial-cell','Explore bacterial cell structures, their functions and how they relate to microbial survival.','beginner'::public.course_level,270,'["Identify major bacterial cell structures","Describe structural roles of membranes and cell walls","Compare common prokaryotic structures"]'::jsonb),
 ('immunology','The Immune Response, Explained','immune-response-explained','Build a foundation in innate and adaptive immunity, immune recognition and memory.','intermediate'::public.course_level,360,'["Compare innate and adaptive immune responses","Explain the roles of antigens and antibodies","Describe immunological memory"]'::jsonb),
 ('general-microbiology','A World of Microbes','a-world-of-microbes','Explore microbial diversity, classification and the scope of modern microbiology.','beginner'::public.course_level,180,'["Describe the breadth of microbial life","Explain basic microbial classification","Recognize microbiology across scientific disciplines"]'::jsonb),
 ('molecular-biology-genetics','Microbial Genetics and PCR','microbial-genetics-pcr','Follow genetic information through microbial cells and learn the principles behind PCR.','intermediate'::public.course_level,420,'["Describe DNA replication and gene expression","Explain the conceptual stages of PCR","Interpret basic molecular biology terminology"]'::jsonb),
 ('environmental-microbiology','Microbes in Our Environment','microbes-in-our-environment','Discover how microbial communities contribute to soil, water and ecosystem processes.','beginner'::public.course_level,240,'["Describe microbial roles in ecosystems","Compare microbial habitats","Explain concepts in biogeochemical cycling"]'::jsonb),
 ('medical-microbiology','Principles of Medical Microbiology','principles-medical-microbiology','Study host–microbe relationships and core concepts in infectious disease microbiology.','advanced'::public.course_level,480,'["Describe host–microbe interactions","Compare pathogen groups","Explain foundational infectious disease concepts"]'::jsonb),
 ('laboratory-techniques','The Microbiology Lab Toolkit','microbiology-lab-toolkit','Understand microscopy, staining, culture media and microbial identification concepts.','beginner'::public.course_level,300,'["Compare foundational microscopy concepts","Explain the purpose of differential staining","Describe culture media and identification concepts"]'::jsonb),
 ('industrial-microbiology','Microbes at Work','microbes-at-work','Explore fermentation, food microbiology and microorganisms in applied bioprocessing.','intermediate'::public.course_level,330,'["Describe microbial fermentation concepts","Explain industrial uses of microorganisms","Compare food and dairy microbiology contexts"]'::jsonb),
 ('medical-microbiology','Foundations of Virology','foundations-of-virology','Study viral structure, replication and diversity through a conceptual introduction to virology.','intermediate'::public.course_level,300,'["Describe common features of viruses","Explain high-level viral replication concepts","Compare broad types of viral diversity"]'::jsonb)
) as v(category_slug,title,slug,summary,level,duration,objectives)
join public.course_categories c on c.slug=v.category_slug
on conflict(slug) do nothing;

-- Two short, safe, conceptual modules per seeded course; staff can expand these in the admin studio.
insert into public.course_modules(course_id,title,description,sort_order)
select c.id,m.title,m.description,m.sort_order from public.courses c
cross join (values (1,'Foundations and vocabulary','Start with key terms and a guided overview.'),(2,'Structures, context and review','Connect the concepts and check your understanding.')) as m(sort_order,title,description)
where c.slug in ('inside-the-microbial-cell','immune-response-explained','a-world-of-microbes','microbial-genetics-pcr','microbes-in-our-environment','principles-medical-microbiology','microbiology-lab-toolkit','microbes-at-work','foundations-of-virology')
on conflict(course_id,sort_order) do nothing;

insert into public.lessons(module_id,title,summary,duration_seconds,sort_order,is_preview)
select m.id,l.title,l.summary,l.duration,l.sort_order,(l.sort_order=1)
from public.course_modules m
cross join (values (1,'Welcome and learning goals','A conceptual orientation to the topic.',480),(2,'Key ideas and scientific context','Build vocabulary and connect core ideas.',720)) as l(sort_order,title,summary,duration)
join public.courses c on c.id=m.course_id
where c.slug in ('inside-the-microbial-cell','immune-response-explained','a-world-of-microbes','microbial-genetics-pcr','microbes-in-our-environment','principles-medical-microbiology','microbiology-lab-toolkit','microbes-at-work','foundations-of-virology')
on conflict(module_id,sort_order) do nothing;

