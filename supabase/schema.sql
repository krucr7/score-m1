-- Student Score Management System (M.1) - Supabase schema
-- Run this file in the dedicated score-m1 Supabase project only.
begin;

create table if not exists public.profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null default '',
  role text not null default 'pending' check (role in ('pending','teacher','admin')),
  created_at timestamptz not null default now()
);

create table if not exists public.classrooms (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  grade_level text not null default 'ม.1',
  academic_year text not null default '2569',
  created_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  unique (name, academic_year, created_by)
);

create table if not exists public.subjects (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  classroom_id uuid not null references public.classrooms(id) on delete cascade,
  term text not null default 'ภาคเรียนที่ 1 / 2569',
  teacher_id uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now()
);

-- These two columns are deliberately named exactly as the web form expects:
-- student_code = รหัสนักเรียน, full_name = ชื่อ-นามสกุล.
create table if not exists public.students (
  id uuid primary key default gen_random_uuid(),
  student_code text not null,
  full_name text not null,
  classroom_id uuid not null references public.classrooms(id) on delete cascade,
  active boolean not null default true,
  pin_hash text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint student_code_nonblank check (length(trim(student_code)) between 1 and 40),
  constraint student_name_nonblank check (length(trim(full_name)) between 1 and 160)
);

-- Upgrade safety for an early score-m1 database where the student table existed
-- but the expected fields had not been added yet.
alter table public.students add column if not exists student_code text;
alter table public.students add column if not exists full_name text;
alter table public.students add column if not exists classroom_id uuid references public.classrooms(id) on delete cascade;
alter table public.students add column if not exists active boolean not null default true;
alter table public.students add column if not exists pin_hash text;
alter table public.students add column if not exists created_at timestamptz not null default now();
alter table public.students add column if not exists updated_at timestamptz not null default now();

create unique index if not exists students_student_code_unique on public.students (lower(trim(student_code)));
create index if not exists students_classroom_code_idx on public.students (classroom_id, student_code);

create table if not exists public.assessments (
  id uuid primary key default gen_random_uuid(),
  subject_id uuid not null references public.subjects(id) on delete cascade,
  title text not null,
  max_score numeric(8,2) not null check (max_score > 0),
  assessment_type text not null default 'งาน/ใบงาน',
  visible_to_students boolean not null default false,
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists public.scores (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references public.students(id) on delete cascade,
  assessment_id uuid not null references public.assessments(id) on delete cascade,
  score numeric(8,2),
  status text not null default 'pending' check (status in ('pending','graded','absent','missing')),
  feedback text,
  updated_by uuid references auth.users(id) on delete set null,
  updated_at timestamptz not null default now(),
  unique (student_id, assessment_id),
  check (score is null or score >= 0)
);

-- Public score lookup throttling. No direct access is granted to browser roles.
create table if not exists public.student_lookup_attempts (
  id bigint generated always as identity primary key,
  student_code text not null,
  ip_hash text not null,
  success boolean not null default false,
  created_at timestamptz not null default now()
);
create index if not exists student_lookup_attempts_recent_idx
  on public.student_lookup_attempts (ip_hash, student_code, created_at desc);

alter table public.profiles enable row level security;
alter table public.classrooms enable row level security;
alter table public.subjects enable row level security;
alter table public.students enable row level security;
alter table public.assessments enable row level security;
alter table public.scores enable row level security;
alter table public.student_lookup_attempts enable row level security;

-- Expose only the privileges required by authenticated teachers. The Edge Functions
-- use server-side credentials for student lookup/PIN writes; never expose those keys.
grant usage on schema public to authenticated;
grant select, insert, update, delete on public.profiles to authenticated;
grant select, insert, update, delete on public.classrooms to authenticated;
grant select, insert, update, delete on public.subjects to authenticated;
grant select, insert, update, delete on public.students to authenticated;
grant select, insert, update, delete on public.assessments to authenticated;
grant select, insert, update, delete on public.scores to authenticated;
revoke all on public.student_lookup_attempts from anon, authenticated;

drop policy if exists profiles_read_self on public.profiles;
create policy profiles_read_self on public.profiles for select to authenticated
using (user_id = (select auth.uid()));
drop policy if exists profiles_update_self_name on public.profiles;
create policy profiles_update_self_name on public.profiles for update to authenticated
using (user_id = (select auth.uid()))
with check (user_id = (select auth.uid()) and role = (select p.role from public.profiles p where p.user_id = (select auth.uid())));

drop policy if exists classrooms_select_owner_teacher on public.classrooms;
create policy classrooms_select_owner_teacher on public.classrooms for select to authenticated
using (created_by = (select auth.uid()) and exists (
  select 1 from public.profiles p where p.user_id = (select auth.uid()) and p.role in ('teacher','admin')
));
drop policy if exists classrooms_insert_owner_teacher on public.classrooms;
create policy classrooms_insert_owner_teacher on public.classrooms for insert to authenticated
with check (created_by = (select auth.uid()) and exists (
  select 1 from public.profiles p where p.user_id = (select auth.uid()) and p.role in ('teacher','admin')
));
drop policy if exists classrooms_update_owner_teacher on public.classrooms;
create policy classrooms_update_owner_teacher on public.classrooms for update to authenticated
using (created_by = (select auth.uid()) and exists (select 1 from public.profiles p where p.user_id = (select auth.uid()) and p.role in ('teacher','admin')))
with check (created_by = (select auth.uid()) and exists (select 1 from public.profiles p where p.user_id = (select auth.uid()) and p.role in ('teacher','admin')));
drop policy if exists classrooms_delete_owner_teacher on public.classrooms;
create policy classrooms_delete_owner_teacher on public.classrooms for delete to authenticated
using (created_by = (select auth.uid()) and exists (select 1 from public.profiles p where p.user_id = (select auth.uid()) and p.role in ('teacher','admin')));

drop policy if exists subjects_access_owner on public.subjects;
create policy subjects_access_owner on public.subjects for all to authenticated
using (exists (select 1 from public.classrooms c where c.id = classroom_id and c.created_by = (select auth.uid()))
  and exists (select 1 from public.profiles p where p.user_id = (select auth.uid()) and p.role in ('teacher','admin')))
with check (exists (select 1 from public.classrooms c where c.id = classroom_id and c.created_by = (select auth.uid()))
  and teacher_id = (select auth.uid())
  and exists (select 1 from public.profiles p where p.user_id = (select auth.uid()) and p.role in ('teacher','admin')));

drop policy if exists students_access_class_owner on public.students;
create policy students_access_class_owner on public.students for all to authenticated
using (exists (select 1 from public.classrooms c where c.id = classroom_id and c.created_by = (select auth.uid()))
  and exists (select 1 from public.profiles p where p.user_id = (select auth.uid()) and p.role in ('teacher','admin')))
with check (exists (select 1 from public.classrooms c where c.id = classroom_id and c.created_by = (select auth.uid()))
  and exists (select 1 from public.profiles p where p.user_id = (select auth.uid()) and p.role in ('teacher','admin')));

drop policy if exists assessments_access_subject_owner on public.assessments;
create policy assessments_access_subject_owner on public.assessments for all to authenticated
using (exists (
  select 1 from public.subjects s join public.classrooms c on c.id = s.classroom_id
  where s.id = subject_id and c.created_by = (select auth.uid())
) and exists (select 1 from public.profiles p where p.user_id = (select auth.uid()) and p.role in ('teacher','admin')))
with check (exists (
  select 1 from public.subjects s join public.classrooms c on c.id = s.classroom_id
  where s.id = subject_id and c.created_by = (select auth.uid())
) and exists (select 1 from public.profiles p where p.user_id = (select auth.uid()) and p.role in ('teacher','admin')));

drop policy if exists scores_access_teacher_owned on public.scores;
create policy scores_access_teacher_owned on public.scores for all to authenticated
using (exists (
  select 1 from public.students st
  join public.classrooms c on c.id = st.classroom_id
  join public.assessments a on a.id = assessment_id
  join public.subjects su on su.id = a.subject_id and su.classroom_id = c.id
  where st.id = student_id and c.created_by = (select auth.uid())
) and exists (select 1 from public.profiles p where p.user_id = (select auth.uid()) and p.role in ('teacher','admin')))
with check (exists (
  select 1 from public.students st
  join public.classrooms c on c.id = st.classroom_id
  join public.assessments a on a.id = assessment_id
  join public.subjects su on su.id = a.subject_id and su.classroom_id = c.id
  where st.id = student_id and c.created_by = (select auth.uid())
) and exists (select 1 from public.profiles p where p.user_id = (select auth.uid()) and p.role in ('teacher','admin')));

-- A pending profile is not allowed to create classes or change grades until a trusted admin
-- explicitly promotes it to role='teacher' or role='admin' in the Supabase SQL Editor.
commit();
