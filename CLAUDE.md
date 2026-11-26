# CLAUDE.md

This file guides Claude Code when working in this repository.

## Project

A website for Shandong University of Science and Technology (SDUST), built as a final project.
It has two parts: the public site, and a logged-in dashboard for students, teachers and counselors.
Both parts are JSP, with a small Java backend (servlets + JDBC, no framework); styling and
behaviour are CSS and jQuery. It is a Maven `war` project deployed to Tomcat, so a backend can be
added later.

## Layout

```
pom.xml                           Maven war build (Jakarta Servlet 6.0, Java 17, OpenPDF 2.4.0 for the PDFs) + Jetty plugin for local runs
deploy.sh                         Builds the WAR and deploys it to the local Tomcat
sql/schema.sql                    MySQL schema for database `webst` (drops and recreates it)
sql/seed.sql                      Sample data for every dashboard page: 25 accounts, courses, timetable, grades, leave, announcements, notifications
src/main/java/edu/sdust/
  db/Database.java                Reads db.properties, hands out JDBC connections (DriverManager, no pool)
  model/User.java                 Logged-in user kept in the session (id, role, name)
  model/Contact.java              Record (email, phone)
  model/Profile.java              Record: personal info for the profile page (student fields or staff fields)
  model/LeaveRequest.java         Record: a leave request with student and reviewer names, plus display helpers (typeText, dateRangeText, ...)
  model/Notification.java         Record: one notification, plus timeText ("Today, 08:15") and isoTime
  model/Exam.java                 Record: an exam with course/teacher names, plus display helpers (dateText, whenText, past, ...)
  model/ClassOption.java          Record: one of a teacher's classes for the exam form (id, course, code, students)
  model/GradeRow.java            Record: one enrollment with course details and score/level/grade point, plus scoreText(tx)
  model/GradeSummary.java         Record: credits earned and GPA of a list of GradeRows (of(rows))
  model/GradeClass.java           Record: one of a teacher's classes for grade entry (course, semester, assessment, students, ungraded, averages)
  model/TeacherCourse.java        Record: one class on My Courses (details, counts, averages, meetings, exams, roster)
  model/TimetableCell.java        Record: one session on the database timetable (day, slot, span, colour, weeks text, time text)
  model/GradeEntryRow.java        Record: one enrolled student on the grade entry page (enrollment id, score, level, grade point)
  model/CounselorStudent.java     Record: one of a counselor's students for My Students (contact, GPA, credits, pending, onLeaveUntil)
  model/Announcement.java         Record: an announcement with author name, plus categoryText, audienceText, fromText, dateText, isoDate
  dao/UserDao.java                authenticate, passwordMatches, updatePassword (bcrypt), findContact, updateContact
  dao/ProfileDao.java             find(id, role): personal info, joined from students/majors/colleges or staff/colleges
  dao/LeaveDao.java               forStudent/forCounselor, create (number + counselor notification), cancel, review, attachment
  dao/NotificationDao.java        forUser(id, limit), markRead(id), markAllRead, clearAll
  dao/GradeDao.java               forStudent(id): every enrollment of the student with course details, newest semester first
  dao/GradeEntryDao.java          classes(teacher), students(class), save (one transaction: only NULL scores, + grade notifications)
  dao/CourseDao.java              forTeacher(id): the teacher's classes with meetings (split weeks merged), exams, roster and averages
  dao/StudentDao.java             forCounselor(id): the counselor's students with GPA, earned credits and leave status
  dao/TimetableDao.java           forUser(id, role): the current semester's class_sessions of a student (enrolled) or teacher (teaching), with student counts and the semester's start date / weeks
  dao/ExamDao.java                forStudent/forTeacher, teacherClasses, create (clash checks + student notifications), remove
  dao/AnnouncementDao.java        forUser(id, role), publicOnes(), byAuthor(id), create (+ bilingual notifications for the audience), remove (author only)
  web/LoginServlet.java           /login: GET shows login.jsp, POST validates, logs in, redirects
  web/LogoutServlet.java          /logout: ends the session, back to /login?logout=1
  web/AuthFilter.java             Guards /dashboard/*: login required, role check, role home redirect, CSRF token
  web/PasswordServlet.java        POST /dashboard/profile/password: change password, JSON reply
  web/ContactServlet.java         POST /dashboard/profile/contact: save email + phone, JSON reply
  web/ProfileFilter.java          On /dashboard/profile: loads `profile` and `contact` (or sets `profileError` / `contactError`)
  web/FormSupport.java            Shared by the form servlets: CSRF token check, JSON reply, value()
  web/CounselorLeaveFilter.java   On /dashboard/counselor/leave: loads `requests` (or sets `requestsError`)
  web/StudentLeaveFilter.java     On /dashboard/leave: loads the student's `requests` (or sets `requestsError`)
  web/LeaveSubmitServlet.java     POST /dashboard/leave/submit (multipart): new leave request, JSON reply (student only)
  web/LeaveCancelServlet.java     POST /dashboard/leave/cancel: student cancels their own pending request
  web/LeaveAttachmentServlet.java GET /dashboard/leave/attachment?id=: download, only for the student or their counselor
  web/UploadStore.java            Saves uploads under $SDUST_UPLOAD_DIR or ~/sdust-uploads (outside the WAR), random names
  web/LeaveReviewServlet.java     POST /dashboard/counselor/leave/review: approve/reject, JSON reply (counselor only)
  web/NotificationFilter.java     On dashboard GETs for every role: loads `notifications` (or sets `notificationsError`)
  web/NotificationServlet.java    POST /dashboard/notifications/read (one `id` or all) and /clear (delete all)
  web/ExamFilter.java             On /dashboard/exams and /dashboard/teacher/exams: loads `exams` (+ teacher `classes`)
  web/ExamServlet.java            POST /dashboard/teacher/exams/save and /remove (teacher only), JSON reply
  web/AnnouncementFilter.java     On the three announcements pages: loads `announcements` (+ `mine` for teachers and counselors)
  web/AnnouncementServlet.java    POST /dashboard/announcements/post and /delete (teacher, counselor), JSON reply
  web/PublicAnnouncementFilter.java On /news-announcements: loads the public announcements (`audience` all) as `announcements`
  i18n/Texts.java                 The request's language (`tx`): get/format message keys, localized dates, `json('js.')` for dash.js
  web/StaticCacheFilter.java      `Cache-Control: no-cache` on /css/* and /js/*
  web/LanguageFilter.java         On every request and error dispatch: picks English or Chinese from the `lang` cookie for JSTL fmt
  web/GradesFilter.java           On /dashboard/grades: loads `semesters`, the chosen `semester` (?semester=), its `grades`, `summary` and `overall`
  web/GradeEntryFilter.java       On /dashboard/teacher/grades: loads `classes`, the chosen class (?class=) as `chosen`, its `rows`
  web/GradeEntryServlet.java      POST /dashboard/teacher/grades/save (teacher only): saves the filled-in grades, JSON reply
  web/TimetableFilter.java        On /dashboard/timetable and /dashboard/teacher/timetable: builds `cells` (TimetableCell) and `timetable` from TimetableDao
  web/TeacherCoursesFilter.java   On /dashboard/teacher/courses: loads `courses` + `currentClasses`, `currentStudents`, `ungraded`
  web/CounselorStudentsFilter.java On /dashboard/counselor/students: loads `students` (or sets `studentsError`)
  web/PdfSupport.java             Shared by the PDF servlets: Noto Sans SC font, colours, bold text, header, download reply
  web/TimetablePdfServlet.java    GET /dashboard/timetable/download (student, teacher): the current semester's timetable as a PDF
  web/LeaveSlipServlet.java       GET /dashboard/leave/slip?id= (student, counselor): an approved request's leave slip as a PDF
  web/LanguageServlet.java        /language?to=en|zh&back=/path: sets the `lang` cookie, redirects back
src/main/resources/db.properties  DB connection settings (url, user, password; never commit real credentials)
src/main/resources/i18n/          messages.properties (English, default) and messages_zh.properties (Chinese)
src/main/resources/fonts/         NotoSansSC-Regular.ttf (static 400 weight cut from Google Fonts' variable Noto Sans SC) + OFL.txt licence, for the PDFs
src/main/webapp/
  index.jsp                       Redirects the site root to /home
  WEB-INF/tags/info.tag           `<t:info field labelKey value>`: one read-only profile field (label is a message key, "Not set" when empty)
  WEB-INF/tags/announcement.tag   `<t:announcement item owner>`: one announcement card (owner adds "To: ..." and Delete)
  WEB-INF/tags/exam.tag           `<t:exam exam teacher>`: one exam card (students see the teacher, teachers the student count + Remove)
  WEB-INF/web.xml                 Maps each public URL to its JSP (`<jsp-file>` servlets), welcome file
  WEB-INF/views/public/           Public site (JSP)
    home.jsp                      /home: hero, stats, news feeds, campus video, about, CTA
    campuslife.jsp                /campuslife: photo hero, number strip, everyday-life photo cards, gallery, alternating year timeline, international
    academics-research.jsp        /academics-research: key numbers, colleges, teaching, faculty, research labs and output (facts from en.sdust.edu.cn)
    news-announcements.jsp        /news-announcements: the public announcements (#announcements), then 12 hard-coded news cards (#news-1..12), CTA
    admissions.jsp                /admissions: programs, Chinese language program, how to apply (#apply), domestic students, admissions office
    login.jsp                     View for LoginServlet: user id, password, "Login as", error/logged-out alert
    partials/navbar.jsp           Shared navbar (params: `active`, `lang`)
    partials/footer.jsp           Shared footer + back-to-top button
  WEB-INF/views/error/
    error.jsp                     Error page for every status code (default `<error-page>` in web.xml), translated, standalone
  WEB-INF/views/shared/           Dashboard (shared by all roles, JSP)
    dashboard.jsp                 Dashboard shell: sidebar, top bar, logout modal, cancel-request modal
    profile.jsp                   /dashboard/profile: basic info, contact info, change password
    timetable.jsp                 Student and teacher timetable from the database: weekly Mon–Sun grid with week navigation
    announcements.jsp             Announcements for all three roles: staff get "Post an announcement" + "Posted by me" above the feed
  WEB-INF/views/student/          Student dashboard fragments (JSP)
    grades.jsp                    /dashboard/grades: semester picker, semester summary (credits, GPA), one card per course
    leave-request.jsp             /dashboard/leave: request form + "My leave requests" table
    exams.jsp                     /dashboard/exams: upcoming and past exams of the student's classes
  WEB-INF/views/teacher/          Teacher fragments, all real data: courses (My Courses), grade-entry, exams
  WEB-INF/views/counselor/        Counselor fragments: leave-requests and students (My Students), both real data
  css/style.css                   Global styles + all home-page sections (loaded by every page)
  css/pages.css                   Inner public pages (loaded after style.css)
  css/login.css                   Login page
  css/error.css                   Error page
  css/dash.css                    Dashboard shell
  css/leaverequest.css            Leave-request fragment and its modal (`lr-` prefix)
  css/profile.css                 Profile fragment
  css/timetable.css               Timetable fragment (`tt-` prefix)
  css/grades.css                  Grades fragment (`gr-` prefix)
  css/announcements.css           Announcements fragment (`an-` prefix)
  css/exams.css                   Exams pages, student and teacher (`ex-` prefix)
  css/students.css                Counselor My Students (`st-` prefix)
  css/courses.css                 Teacher My Courses (`co-` prefix; reuses `gr-meta`, `st-stats`, `ge-table`)
  css/gradeentry.css              Teacher grade entry (`ge-` prefix; it also reuses the `gr-card` / `gr-pick` / `gr-stats` cards from grades.css)
  js/script.js                    Public-site behaviour (jQuery)
  js/dash.js                      Dashboard behaviour (jQuery)
  assets/                         logo-blue.webp / logo-white.webp (900px wide), favicon.png (256px), campus-video.mp4 (muted home loop, H.264, no audio), campus-aerial.jpg (hero, video poster, login), campus-gate-aerial.jpg (footer), campus-spring-avenue.jpg; campus-*.jpg photos from en.sdust.edu.cn (max 1200px, ~100–150 KB), used by the news cards (one per story, same on home and the News page) and the Academics / Admissions sections
```

## Current state / known issues

- Deploy to the local Homebrew Tomcat 11 with `./deploy.sh`: it builds the WAR, replaces `sdust.war`
  in `webapps/`, starts Tomcat if needed and waits for http://localhost:8080/sdust/ to answer 200.
  Set `TOMCAT_HOME` to use another Tomcat. Or run with `mvn jetty:run` (stop Tomcat first, same port).
  `mvn package` builds `target/sdust.war` for Tomcat 10.1+ (Jakarta namespace; Tomcat 9 won't work).
  The JSPs can't be opened straight from disk.
  `pom.xml` sets `project.build.outputTimestamp` to the build time: without it every file in the WAR is
  dated 1980 and browsers keep serving old CSS/JS after a deploy. The archiver stores that time as UTC
  wall-clock values, which Tomcat reads as local time (8 hours early in China), so `deploy.sh` passes the
  local time as `-Dproject.build.outputTimestamp` to get the right dates. `StaticCacheFilter` also sends
  `Cache-Control: no-cache` for `/css/*` and `/js/*`, so browsers re-check them on every load (304 if
  unchanged) and pick up a new deploy without a hard refresh.
- The app connects to the local MySQL `webst` database as user `sdust` (settings in `db.properties`).
  Public pages and dashboard pages are routed by `<jsp-file>` mappings in `web.xml`; add a public page
  by adding a JSP and a servlet + mapping there. `/login` and `/logout` are annotated servlets
  (`@WebServlet`), so they must not also be mapped in `web.xml`. Sessions are cookie-only, HttpOnly,
  30-minute timeout (`<session-config>` in `web.xml`).
- `webst` is loaded with the schema and seed data. `sql/schema.sql` starts with
  `DROP DATABASE IF EXISTS webst` (needs root: `mysql -u root -p < sql/schema.sql`). The `sdust` user
  can't create or drop databases but owns `webst`, so to reset it without root, drop the tables and run
  `{ echo "USE webst;"; sed '1,3d' sql/schema.sql; } | mysql -u sdust -p` then
  `mysql -u sdust -p < sql/seed.sql`. Tested on the local MySQL (26.10). The schema creates triggers, and
  with binary logging on a user without SUPER gets error 1419, so the non-root reset needs
  `log_bin_trust_function_creators` on (as root, once: `SET PERSIST log_bin_trust_function_creators = ON;`).
  The files use `DELIMITER //` for the triggers, which works with `mysql < file` and the piped command. Tables:
  - `users`: `id` VARCHAR(20) is the student or staff id itself (primary key, what people log in with; there is
    no separate username or numeric id), bcrypt `password_hash`, `role` student/teacher/counselor, name, gender, email, phone.
    Every reference to a person is that id: `students.student_id`, `staff.staff_id`, `counselor_id`,
    `teacher_id`, `reviewer_id`, `author_id`, `notifications.user_id` are all VARCHAR(20) → `users(id)`
  - `colleges` (1 Computer Science and Engineering, 2 International Exchange), `majors`
  - `students` (`student_id` → users): major, `counselor_id` → users, enrollment year, class, campus
  - `staff` (`staff_id` → users): college, title, office for teachers and counselors
  - `semesters` (`name` like 2026-2027-1, `start_date` = Monday of week 1, `weeks`): only 2026-2027-1 (2026-08-31, 19) is
    seeded; both timetables read it.
  - `courses` (code, name, credits, `hours`, `nature` foundation/core/practice/general/elective (课程性质), `attribute`
    required/elective, `assessment` exam (考试) / assessment (考查), college), `course_classes` (a course taught by a teacher in a semester), `class_sessions`
    (day 1–7 = Mon–Sun, periods, `start_week`/`end_week`, location: the timetable), `enrollments` (student in a class,
    score, `grade_level` excellent/good/medium/pass/fail for 优/良/中/及格/不及格 grades, `exam_nature`
    normal/makeup/retake, grade point: grades). A word grade is stored with its score equivalent (优 95, 良 85,
    中 75, 及格 65, 不及格 0), which gives the real grade points. A session has one contiguous week range, so non-contiguous weeks are several rows
    with the same day and periods (weeks "1–6, 8" are 1–6 and 8–8; "1–9, 11–12" are 1–9 and 11–12).
  - Grades are final once entered, enforced by triggers on `enrollments`: `enrollments_grade_update` refuses
    any change to a non-NULL `score` (including clearing it) with SQLSTATE 45000 'Grade is final and cannot
    be changed'. When `score` goes from NULL to a value (`enrollments_grade_insert` / `_update`) the trigger
    sets `graded_at = NOW()` and `grade_point` from SDUST's 5-point scale: ROUND((score − 50) / 10, 1) for 60 and above
    (60 → 1.0, 71 → 2.1, 100 → 5.0), 0 below 60. Changing `grade_level` of a graded row is refused too. The application only
    writes `score` (once, from NULL); it never writes `grade_point` or `graded_at`, and the triggers overwrite
    them if it tries. Catch SQLSTATE 45000 in Java to tell the teacher the grade is already final.
  - `leave_requests`: same `leave_type` values as the form, `status` pending/approved/rejected/cancelled
    (Cancel sets `cancelled`, it doesn't delete), `request_no` like `LR-2026-0131`, reviewer, comment, attachment.
    Duration isn't stored; compute it from `start_date`/`end_date`.
  - `announcements`: author, department, `category` academic/exams/international/student/campus, title,
    summary, body, `audience` all/student/teacher/counselor, published_at (there is no pinning: announcements are always newest first). `author_id` NULL is a
    university-wide notice (its `department` is the office, e.g. "Academic Affairs Office"); otherwise it is the
    teacher or counselor who posted it to a whole role, and `department` is that author's college name.
    `idx_announcement_author (author_id, published_at)` serves "my posted announcements".
  - Who an announcement reaches: `all` is **public** (every account, plus the public `/news-announcements` page);
    `teacher` every teacher; a counselor's `student` post only the students whose `students.counselor_id` is that
    counselor; a teacher's post only the students of its `announcement_classes`; a `student` post with no author
    (an office) every student.
  - `announcement_classes` (`announcement_id`, `class_id` → course_classes, both cascade): a teacher's announcement
    is for the students of these classes only (audience `student`). No rows means the whole audience.
  - `exams`: one per class and `exam_type` (midterm/final/makeup, unique), `exam_date`, `start_time` / `end_time`,
    location, notes, `created_by`. Teachers create them for their classes in the current semester (the latest
    `course_classes.semester`).
  - `notifications`: per user, `type` announcement/leave/grade/timetable/exam, title, message, `title_zh`, `message_zh`, link (a path without
    the context path, e.g. `/dashboard/leave`), is_read. Counselors get them too: `leave` when one of their
    students submits a request (link `/dashboard/counselor/leave`), `announcement` for new announcements.
    Students get `exam` ones when an exam of their class is scheduled or cancelled (link `/dashboard/exams`).
- JSPs live under `WEB-INF/` and are reached only through their `web.xml` routes, never by file path.
- In JSPs, every asset and page link starts with `${pageContext.request.contextPath}`, e.g.
  `${pageContext.request.contextPath}/css/style.css`, `${pageContext.request.contextPath}/home`.
  Never use `../../../` or `.html` links there. `<jsp:include>` paths must be absolute
  (`/WEB-INF/views/public/partials/...`); relative ones resolve against the URL and fail.
- Every error (404 for unknown URLs, missing files and `/WEB-INF/...`, 405, 500 for uncaught exceptions, ...)
  shows `error.jsp` in the visitor's language. It reads the code from `jakarta.servlet.error.status_code`,
  shows "Error <code>" with `error.404` for 404 or the "something went wrong" `error.other` for any other code, and
  draws the big background number from `data-code`. It never shows exception details.
  `LanguageFilter` also runs on the ERROR dispatch, because Tomcat rejects `/WEB-INF/` URLs before any
  filter sees the request. Unknown `/dashboard/*` URLs redirect to the role home instead.
- Login is real: `LoginServlet` checks that id and password are filled in, then the id format, the bcrypt
  hash in `users`, and that "Login as" matches the account's role. Every credential failure (bad format,
  unknown id, wrong password, wrong role) gets the same message, "Incorrect id, password or role", so the
  page never reveals id formats, which ids exist or which role an account has. Keep it that way. All three
  roles can log in. On success the old session is discarded, a new one stores `user` (`edu.sdust.model.User`), and the
  user goes back to the dashboard page they first asked for (saved as `next` by `AuthFilter`) or
  `/dashboard`, which `AuthFilter` sends to the role's home: student `/dashboard/timetable`, teacher
  `/dashboard/teacher/timetable`, counselor `/dashboard/counselor/leave`. Visiting `/login` while logged in redirects to `/dashboard`. Sample accounts, all with
  password `Sdust2026`:
  - students (major Software Engineering, enrolled 2024, Qingdao): `202411070169` (Aimad Kouchaid, the real
    student), `202411070142` (Fatima Zahra El Idrissi), `202411070155` (Daniel Mensah), `202411070163` (Sofia
    Petrova) in Software Engineering 2024-1 with counselor `C1024` (Zhou Lin); `202411070177` (Nurlan Abenov),
    `202411070181` (Mariam Diallo), `202411070186` (Kevin Otieno), `202411070193` (Lina Haddad) in Software
    Engineering 2024-2 with counselor `C1025` (Liu Yang). Everyone but 202411070169 is made up.
  - teachers: `T2031` (Yuan Guiyuan), `T2032` (Qi Liang), `T2033` (Ni Lina), `T2034` (Fu Xiao), `T2035` (Wang Ting),
    `T2036` (Dongye Changlei), `T2037` (Xu Shixiao) teach the real 2026-2027-1 timetable (title and office not set);
    the made-up `T2040` (Chen Hao), `T2041` (Sun Yue), `T2042` (Zhao Lei), `T2043` (Huang Jing), `T2044` (Ma Qiang)
    and `T2045` (Gao Min, International Exchange) teach the 2025-2026-2 courses; `T2038` (Wang Fang), `T2039`
    (Zhang Min) and T2031 teach the older sample semesters.
  The seed has 27 courses over 2024-2025-1 to 2026-2027-1. All 8 students take the same 9 classes in 2026-2027-1
  (the real timetable, Mon–Fri, weeks 1–19, semester start 2026-08-31, all ungraded) and the same 12 graded
  2025-2026-2 courses (202411070169's real transcript: GPA 3.44; the others have made-up results, Nurlan Abenov
  failed Computer Networks at 55). Only 202411070169 has the older sample semesters (Advanced Mathematics II failed
  at 52). It also has 4 exams, 8 leave requests (LR-2026-0104 keeps Nurlan Abenov on leave Nov 24–27, three are
  pending), 8 announcements and 14 notifications.
  The navbar Login dropdown links go to `/login?role=student|teacher|counselor`. When someone is logged
  in (`sessionScope.user`), the navbar shows a "Dashboard" button to `/dashboard` instead, on every public page.
  Every "Apply now" button links to `/admissions` (on Admissions itself, to `#apply`). The home news cards link
  to their story on `/news-announcements#news-<n>`. Login has a "Forgot password?" button (`.login-forgot`) that
  slides `#forgot-note` ("contact your counselor") down and up (`script.js`); passwords can't be reset online.
  "Apply now" (`.btn-primary`) and "Apply online" (`.ar-btn`) end with `<span>→</span>` like the other buttons; the
  arrow moves right on hover.
- `/dashboard/*` needs a logged-in user (`AuthFilter`; logged-out visitors go to `/login?role=` for the
  role in the URL) whose role is listed in that route's `roles` init-param; otherwise, and for unknown
  dashboard URLs, it redirects to the user's role home. Responses are is sent with `Cache-Control: no-store`, so
  Back after logout doesn't show it. The top bar's title ("Student Dashboard", "Teacher Dashboard",
  "Counselor Dashboard"), name, initial and role come from `sessionScope.user`; print user data with `<c:out>` / `fn:escapeXml` (JSTL 3 taglibs
  `jakarta.tags.core` / `jakarta.tags.functions`). Change password, contact info and leave requests save (see **Profile forms** and **Leave requests**).
- The profile page shows real data for every role. Personal info is read-only: students see name, gender,
  student id, college, major, class, enrollment year, campus and counselor; teachers and counselors see
  name, gender, staff id, role, college, title and office. Contact info and change password save.
  Leave requests work end to end: students submit and cancel (see **Leave requests**), counselors review
  (see **Counselor leave review**), the notifications bell is real, and exams work (see **Exams**).
  Announcements work for every role (see **Announcements**), and so does the counselor's My Students page
  (see **My students**). The timetable can be downloaded as a PDF and approved leave requests as a leave slip
  (see **PDF downloads**), and students see their grades (see **Grades**). Both timetables
  come from the database; teachers enter grades (see **Grade entry**) and have My Courses (see **Teacher pages**). The
  notifications bell is shown to every role.

## Conventions

**Public pages** are JSPs starting with
`<%@ page contentType="text/html;charset=UTF-8" pageEncoding="UTF-8" %>`. They load jQuery 3.7.1 from
`code.jquery.com` and `js/script.js`. Don't copy the navbar or footer: include them with
`<jsp:include page="/WEB-INF/views/public/partials/navbar.jsp">` plus
`<jsp:param name="active" value="..."/>` (`home`, `academics`, `news`, `admissions`, `campus`), which
sets `class="active"` on that link. The footer and
back-to-top button come from `<jsp:include page="/WEB-INF/views/public/partials/footer.jsp"/>`;
they sit in the fixed bottom-right `.float-actions` stack with the always-visible `.language-btn` below
back-to-top: a filled blue pill with a globe and the other language's name ("中文" or "English"), which
pulses 4 times after load. It shows on every page that includes the footer; login has its own
`.login-lang` pill at the top of the form. Both link to `/language` (see **Languages**).
Nav: Home, About (`/home#about-us`), Academics & Research, News & Announcements, Admissions,
Campus Life, plus a Login dropdown. Inner pages use
`<header class="hero-header">` with the navbar only, then `<div class="page-container">` with an
`<h1 class="page-title">Word <strong>Word</strong></h1>`, and end with the `#cta` and contact sections.
Login and error pages are standalone (no navbar or footer).

**Dashboard pages** all render `shared/dashboard.jsp` (sidebar + `.dashnav` top bar, jQuery and
`js/dash.js`, not `script.js`; it loads every dashboard stylesheet: `leaverequest.css`, `profile.css`, `timetable.css`, `grades.css`, `announcements.css`, `exams.css`, `students.css`, `gradeentry.css`, `courses.css`, `dash.css`). Each route is
its own servlet in `web.xml` pointing at `dashboard.jsp`, with four `<init-param>`s: `active` (the
sidebar link to highlight: student `timetable`, `grades`, `exams`, `leave`, `announcements`; teacher
`teacher-timetable`, `teacher-courses`, `teacher-grades`, `teacher-exams`, `teacher-announcements`; counselor
`counselor-leave`, `counselor-students`, `counselor-announcements`; shared `profile`), `title` (a message key
like `dash.nav.timetable`, printed with `fmt:message`), `content` (absolute path of the fragment JSP, included into `.page-container`) and `roles`
(comma-separated roles allowed to open it, checked by `AuthFilter`; a route without it is closed to
everyone). The shell reads them with `${pageContext.servletConfig.getInitParameter('...')}` (`active` is
put in `${active}`) and picks the sidebar links with `<c:choose>` on `sessionScope.user.role`. Student
URLs are `/dashboard/<page>`, teacher `/dashboard/teacher/<page>`, counselor `/dashboard/counselor/<page>`.
To add a page, write a fragment JSP, add a servlet + mapping with its `roles`, and a sidebar link. Fragments are just the page directive plus content: no `<html>`,
`<head>`, `<body>`, stylesheets or scripts. Section headings are
`<h1 class="pgtitle">`. Sidebar links use `.sidelink`, and the current one gets `active`. The sidebar
collapses via `.sideaction`, which toggles `body.sd-collapsed`, and shows `.sdtip` tooltips while collapsed.
At 1000px and below the sidebar becomes an off-canvas drawer instead: `.sideaction` toggles `body.sd-open`,
and the `.sdbackdrop`, Escape or resizing back up close it (`sd-collapsed` is ignored there). The top
bar's bell (`.ntf`) opens the `.ntf-panel` dropdown (`.ntf.open`); `.ntf-item.unread` items drive the
`.nbadge` count, and clicking one or "Mark all as read" clears it. It closes on outside click and Escape.
The bell lists the user's 20 newest rows from `notifications`, and `.ntf` carries `data-read-url` + `data-csrf` so clicking an item
(`data-id`; it waits for the save before following the link, Ctrl/Cmd-click uses `navigator.sendBeacon`) or "Mark all as read" is saved through `NotificationServlet`. The head's
`.ntf-actions` also has `.ntf-clear` ("Clear all"): one click posts to `data-clear-url` (no confirmation),
which deletes all of the user's notifications, and the list shows `.ntf-empty`. Both buttons are disabled when there is nothing to do.

**CSS**
- Colours come from the `:root` variables in `style.css`: `--color-primary` (#004A9F), `--color-primary-dark`,
  `--color-text`, `--color-white`. Don't hard-code new brand colours.
- Fonts: Manrope + Noto Sans SC (Google Fonts import at the top of `style.css`).
- Home-page section styles go in `style.css`. Inner public pages go in `pages.css` with a page prefix
  (Campus Life uses `cl-`). Other pages get their own stylesheet (`login.css`, `dash.css`, ...), loaded after `style.css`.
- Breakpoints in use: 1200, 1000 (navbar switches to the hamburger), 768, 560/640, 480, 380px.
- Responsive sizing favours `clamp()` and `minmax(0, 1fr)` grids.
- To stop sideways scrolling, use `overflow-x: clip`, not `overflow-x: hidden`. `hidden` turns the
  element into a scroll container (`overflow-y` becomes `auto`), which broke page scrolling on `main`.
  `body` and `main` already use `clip`.

**Responsiveness**: every page (public site, login, error page and all dashboard pages for each role) must fit
1440, 1280, 1000, 768, 480, 375 and 320px without sideways scrolling, also while load animations run. Inner public
pages clip sideways overflow on `.page-container` (`overflow-x: clip`), because their sections slide in from the
side on load. Never animate `transform: scale` on an element near the screen edge (it widens the page); the
`.language-btn` pulse uses an expanding `box-shadow` for that reason. Status pills (`.lr-status`) never wrap.

**Dashboard responsiveness**: Wide tables sit in `.lr-tablewrap` (`overflow-x: auto`, `position: relative` so absolutely positioned
children like `.lr-sr` can't escape it and widen the page). At 640px and below `.st-table` and `.ge-table` turn
into cards: the header row hides, each row is a block, and every cell but the first shows its `data-label`
(a `fmt:message`) on the left with the value right-aligned; give every new cell of these tables a `data-label`.
The counselor leave table hides its Type column at 640px. On phones the top bar keeps `.navactions` from
shrinking. `.pgtitle` is 28px, 24px at 768px, 21px at 480px and 19px at 380px (section headings 16px on phones).
The timetable's `.tt-head` keeps the title and `.tt-download` on one centred line at every width. Both timetables show `.tt-empty` ("No classes this week") when the shown week has no class.

**Dashboard animations** (`dash.css`, prefix `dash-`): the direct children of `.page-container` fade up one
after another (`dash-in`), and so do the cards of each list (`.ex-item`, `.an-item`, `.gr-course`, `.co-card`,
`.st-stat`, `.gr-stats li`, `.tt-session`; delays by `nth-child`); table rows (`.lr-item`, `.st-row`, `.ge-row`)
fade in (`dash-fade`); cards lift 3px on hover; `.gr-score` and an unread `.nbadge` pop in (`dash-pop`), and
the bell rings once (`dash-ring`) when there are unread notifications; sidebar icons nudge on hover; the main
buttons press in on `:active`. `dash.js` counts the numbers in `.st-stat strong`, `.gr-stats strong` and
`.ex-count` up from 0 (decimals kept). The `prefers-reduced-motion` block turns all of it off, and the count-up
is skipped.

**Public page headings**: the page title (`.page-title`, 28px, 24px at 640px) stands alone: there is no intro
paragraph under it. Section headings are `.cl-heading` (centred) or `.cl-split-text` (left), plus the
announcements heading in `.na-section`: a `.cl-label` pill (light blue background, dot, uppercase) above an `h2`
(26–34px) whose second word is a blue `span`, followed by a short blue underline (`h2::after`). Campus Life adds
`.cl-hero` (photo banner with the label/title/text on a blue gradient), `.cl-stats` (four number cards overlapping
the hero) and `.cl-life` (photo cards with a `.cl-life-icon` badge); its `.page-intro.cl-intro` paragraph sits
under the number cards.

**Scroll animations** (home page only): put `data-animate` on a section. On the home page (detected by
`#uni-data`) `script.js` adds `.anim-ready`, then toggles `.in-view` when 30% of it is visible, and removes it once
the section is fully off-screen, so the entrance replays. On every other public page (and under reduced motion)
it adds `.in-view` to all `data-animate` sections at once, so they animate a single time on load. The dashboard only
has load animations too. In CSS:
- hide children with `.x.anim-ready:not(.in-view) ...  { opacity: 0; }`
- animate with `.x.in-view ... { animation: fade-up ... backwards; }`

The shared keyframes `fade-up`, `fade-down`, `fade-left`, `fade-right`, `pop-in` and `letter-spread`
are in `style.css`. Every stylesheet has a `prefers-reduced-motion: reduce` block that turns the
animations off; keep one in any new stylesheet.

**JS**: one `$(document).ready` per script file. Guard each feature with `if ($el.length)` so it is
safe on pages that don't have that section. Check for `IntersectionObserver` support and reduced
motion first (`dash.js` sets jQuery animation speed to 0 under reduced motion). Modals open with
`css("display", "flex").hide().fadeIn()` and close on the close button, backdrop click and Escape.

**Leave requests**: each request is a `<tbody class="lr-item">` with `data-id`, `data-status`
(`pending` / `approved` / `rejected` / `cancelled`) and `data-submitted` (`YYYY-MM-DD`). `dash.js` sorts pending
first, then newest, expands one row at a time, and shows `.lr-empty` when none are left. The student page
lists the student's requests from the database. The `.requestaleave` form (multipart, CSRF token) is
checked with `bindValidation` (which also covers `textarea` and `select`; rules get `(value, $input)`) and
posted with `FormData` to `LeaveSubmitServlet`. Server rules, mirrored in the browser: type is one of the
four, start no more than 7 days ago and within a year, end not before start, at most 30 days, destination
1–100 chars, contact an 11-digit Chinese mobile (saved as digits), reason 10–1000 chars, attachment
optional PDF/JPG/PNG/DOC/DOCX up to 5 MB, and no overlap with the student's pending or approved requests
(409). The request gets the next `LR-<year>-NNNN` number and the counselor gets a `leave` notification in
the same transaction; the reply's fields fill the hidden `#lr-template` row, which is added at the top.
Attachments are stored outside the WAR by `UploadStore` (random file name in `attachment_path`, the cleaned
original name in `attachment_name`) and downloaded through `LeaveAttachmentServlet` (`Content-Disposition:
attachment`, `nosniff`). Cancel (modal) posts to `LeaveCancelServlet`, which only cancels the student's own
pending requests; the row stays, marked Cancelled.

**Exams**: students see `/dashboard/exams` (Upcoming, then Past, of every class they're enrolled in);
teachers schedule at `/dashboard/teacher/exams` with `.ex-form` (class, type, date, start/end time, room,
notes) and see their exams below, newest last, past ones dimmed. Both render `<t:exam>` cards. The form is
checked with `bindValidation` and posted (CSRF) to `ExamServlet`, which re-checks: own class this semester,
date from today to a year ahead, 07:00–22:00, end after start, at most 4 hours, room 1–100, notes up to 500.
In one transaction `ExamDao.create` refuses a second exam of the same type for the class, a room already
booked at an overlapping time, or an overlap with another exam any of the class's students has (409, the
message names the clashing exam), then inserts it and an `exam` notification for every enrolled student.
The reply fills `#ex-template`, placed in date order. Remove needs a second click ("Confirm remove", resets
after 4 s); only upcoming exams of the teacher's own classes can be removed, and students are notified.

**Counselor leave review**: `/dashboard/counselor/leave` lists the requests of the counselor's own students
(`students.counselor_id`), pending first, reusing the `lr-` table (one more column, Student; `data-id` on each
`.lr-item`; statuses include `cancelled`). `.lr-filter` chips (All, Pending, Approved, Rejected, Cancelled)
show counts and filter the rows. A pending request has a `.lr-review-form` with a comment (required to
reject, max 500) and `.lr-approve` / `.lr-reject`, posted with the CSRF token to `LeaveReviewServlet`. It only
reviews pending requests of that counselor's students (404 / 409 otherwise), saves status, reviewer, comment
and `reviewed_at`, and adds a `leave` notification for the student ("Leave request approved/rejected") in the
same transaction. The page then swaps the form for an `.lr-review` block.

**Languages**: the whole site is English or Simplified Chinese: public pages, login, error page and the
dashboard (the dashboard top bar has a `.dash-lang` pill to `/language`, just the globe at 480px and below).
`LanguageFilter` reads the `lang` cookie (`en` default, `zh`), sets the JSTL fmt localization context
and locale, and puts `lang`, `htmlLang` (`en` / `zh-CN`, used as `<html lang="${htmlLang}">`) and
`currentPath` (the URL to return to) in the request. Never hard-code text on a public page: add a key to
both `i18n/messages.properties` and `messages_zh.properties` (UTF-8) and print it with
`<fmt:message key="..."/>` (taglib `jakarta.tags.fmt`). Messages are printed as HTML, so write `&amp;`
for `&`. Missing Chinese keys fall back to English. Dates use `fmt:parseDate` + `fmt:formatDate
dateStyle="medium"` ("Nov 18, 2026" / "2026年11月18日"). `LoginServlet` passes message keys
(`login.error.*`), not text, and login.jsp prints them with `fmt:message`; the browser-side login
messages and id label/placeholder come from `data-*` attributes on `.login-form`. Chinese names: 山东科技大学,
学号 (student id), 工号 (staff id), 辅导员 (counselor).

In the dashboard, `LanguageFilter` also puts a `Texts` (`edu.sdust.i18n.Texts`) in the request as `tx`. JSPs print
keys with `fmt:message` or `${tx.get('key')}` / `${tx.format('key', arg)}`; model display helpers take it as an
argument (`${r.typeText(tx)}`, `durationText(tx)`, `exam.whenText(tx)`, `a.audienceText(tx)`, `n.timeText(tx)`),
and labels for stored codes are keys (`leave.type.<type>`, `leave.status.<status>`, `exam.type.<type>`,
`an.cat.<category>`, `gender.<gender>`, `dash.role.<role>`). Dates go through `Texts` with the patterns in the
`fmt.*` keys ("Nov 23, 2026" / "2026年11月23日"). Servlets reply with `Texts.of(req).get(...)` /
`.format(...)`, never English literals; JSON fields meant for display (`typeText`, `statusText`, dates) are
localized too. `dash.js` never hard-codes text: `dashboard.jsp` writes every `js.*` key as JSON into
`<script type="application/json" id="dash-i18n">` (`tx.json('js.')`), and `dash.js` reads it with `T(key, args...)`
(`{0}` placeholders) and `TN(key, n)` (picks `key.one` / `key.many`); JSPs reuse `js.*` keys for the same text.
`Texts.get` turns `&amp;` back into `&`, so keys can still be printed as HTML. Keys used with arguments are
`MessageFormat` patterns: write ’ instead of ' in them. Course names, people's names, rooms, announcement and
leave text are data and are shown as stored. Notifications are stored in both languages when they are created:
the DAOs build `title`/`message` and `title_zh`/`message_zh` from the `ntf.*` keys with `Texts.forLanguage("en")` and
`Texts.forLanguage("zh")` (`Texts.fit` cuts them to the column size), and the bell prints `n.titleText(tx)` /
`n.messageText(tx)`, which fall back to English when the Chinese column is empty.

**Content**: English, plus the Chinese translations in `messages_zh.properties`. Facts about SDUST already used on the site: founded 1951, 40,000+ students,
70+ undergraduate programs, 3 campuses (Qingdao, Tai'an, Jinan), ~1,500 international students. Academics & Research
and Admissions use the official en.sdust.edu.cn and cie.sdust.edu.cn figures (73 majors, 11 doctoral / 33 master's
first-level disciplines, 23 professional master's categories, 10 postdoctoral stations, 8 ESI top-1% disciplines,
3,300+ staff, key labs, research output since 2021, admissions email admission@sdust.edu.cn, CIE phone
+86 532 8605 7717, online application at sdust.at0086.cn/student). The official site gives no tuition, deadlines,
entry requirements or scholarship details, so the pages point to the College of International Exchange for those. The
main campus is at 579 Qianwangang Road, Huangdao District, Qingdao. News items are sample content.
The site follows the Chinese university system. Semesters are written `YYYY-YYYY-N` (academic year +
term number), never "Fall 2026"/"Spring 2026": `2026-2027-1` is the autumn term starting Sep 2026,
`2026-2027-2` the spring term in 2027. Use the same string in the UI, in `data-semester` and in the
`course_classes.semester` column.

**Timetable**: `shared/timetable.jsp` serves both roles from `TimetableFilter` (students see the teacher's name,
teachers the student count). `.tt-toolbar` has `data-semester-start` (the Monday of week 1, `YYYY-MM-DD`, from the
`semesters` table; 2026-2027-1 starts 2026-08-31, so week 13 is Nov 23–29) and `data-weeks` (19). The grid is Mon–Sun × 5 slots (periods 1–2, 3–4,
5–6, 7–8, 9–10): `96px` time column plus 7 equal day columns, `min-width: 900px`. It stays a table at every width:
when the screen is narrower it slides sideways inside `.tt-wrap`, with the time column (`.tt-corner`, `.tt-time`)
sticky on the left. At 768px and below the time column is 70px and the grid 860px wide (course names 12.5px,
marked `lang="en"` so they hyphenate) so words fit their cells. Each `.tt-session` is placed with `tt-day-1..7` and `tt-slot-1..5` (`tt-span-2` for a double
slot), coloured with `tt-c1..6`, and has `data-start-week` / `data-end-week`: one element per week range, like
the `class_sessions` rows, with the full pattern in `.tt-weeks` ("Weeks 1–9, 11–12"). `dash.js` works out the
current week, fills in the dates of all 7 days, highlights today (weekends too), and dims (`tt-off`) sessions
outside the shown week; when several elements share a cell it shows only the one running that week (or the first,
dimmed) and hides the rest with `tt-hidden`. The 35 empty `.tt-cell`s draw the grid lines.

**Announcements**: one fragment, `shared/announcements.jsp`, serves `/dashboard/announcements`,
`/dashboard/teacher/announcements` and `/dashboard/counselor/announcements`. Everyone sees the rows whose `audience` is
`all` or their role, but students only see class announcements (`announcement_classes`) of classes they're enrolled
in and counselor posts of their own counselor (newest first, up to 200). Each card is `<t:announcement>`: `<article class="an-item">`
with `data-id`, `data-category` and `data-date` (`YYYY-MM-DD`); `.an-excerpt` (the summary) is always
shown and `.an-body` (the body, plain text, `white-space: pre-line`) slides open with `.an-toggle`. `dash.js` sorts
newest first, adds a "New" tag to items from the last 2 days, and filters by `.an-chip` and the
`#ansearch` text. Teachers and counselors see it all on one page: "Post an announcement" with the `.an-form` (category; who can see it: counselors pick My students (`student`), All teachers (`teacher`) or Public (`all`), teachers pick "All my students"
(`mine`, every class of theirs this semester) or one of their classes this semester (class id); title 5–200, summary 10–500, full
text 10–5000), then "Posted by me" (`.an-mine`), then the feed. The form is checked with `bindValidation` and posted (CSRF) to `AnnouncementServlet`, which re-checks it. In one
transaction `AnnouncementDao.create` inserts the row (`department` = the author's college) and an `announcement`
notification ("New announcement", "<author>: <title>", link to that role's announcements page) for every user in
the audience except the author (a counselor's `student` post: only their students); for a teacher's post it adds the `announcement_classes` rows and notifies only the
students enrolled in those classes. "To: ..." on the author's own cards comes from
`Announcement.audienceText()` ("Students of <course names>", "My students", "Teachers", "Public").

The public `/news-announcements` page lists the `all` announcements (`PublicAnnouncementFilter`, newest 50) as `.na-item` cards (`na-` prefix in `pages.css`); the page text is translated (`news.ann.*` keys, category
names `news.ann.cat.<category>`), the announcement text itself is shown as written. The reply fills `#an-template`, added to the top of `.an-mine` and, if the author's
own role is in the audience, to the feed. Delete needs a second click ("Confirm delete", resets after 4 s) and only
deletes the author's own rows; notifications already sent stay.

**Login messages**: one `#login-alert.login-alert` box right above the Login button, never per field. It
is `.error` (server error, or the browser's "Please enter your student id / password" for empty fields,
with a shake) or `.info` ("You have been logged out."), and `hidden` when empty. The browser only checks
that fields are filled in; never show id-format or password rules on the login page.

**Form validation** (profile forms; the server must re-check everything once it exists): forms have
`novalidate`, and each input has a `<p class="field-error" id="<input id>-error" aria-live="polite">` right
after it, linked with `aria-describedby`. A field is checked on blur
once it has a value, re-checked on every keystroke while it's `.invalid`, and all fields are checked on submit,
which focuses the first invalid one. Errors set `.invalid` + `aria-invalid` and fill the `.field-error`. Rules:
email `name@domain.tld` up to 100 chars; phone an 11-digit Chinese mobile (`1[3-9]` + 9 digits, optional
`+86`, spaces/dashes allowed); new password 8–64 chars with a letter and a number, different from the
current one, with a live `.pass-rules` checklist (`li.met`); confirm must match. Profile uses
`bindValidation($form, rules)` in `dash.js`.

**Profile forms**: both forms post with jQuery `$.ajax` and show the reply in their `.form-status`.
Contact info: the fields are filled from the database (`ProfileFilter` puts `contact` in the request;
print it with `fn:escapeXml`). `.contactinfo` posts to `/dashboard/profile/contact` (`ContactServlet`),
which re-checks the email and phone rules, saves the phone as 11 digits (spaces, dashes and `+86`
removed), answers "Nothing to save" if nothing changed, and returns the saved `email` / `phone`, which
the page puts back in the fields. The browser also refuses to send an unchanged form.
Change password: `.changepass` posts to `/dashboard/profile/password`
(`PasswordServlet`). Both servlets are annotated with a `roles` init-param for all three roles, so `AuthFilter` guards them.
`AuthFilter` puts a random `csrf` token in every logged-in session; forms that change data send it as a
hidden `csrf` field and the servlet checks it with `FormSupport.tokenMatches` (constant time, 403 if wrong). The servlet re-checks
every rule, verifies the current password with bcrypt, saves a new bcrypt hash and calls
`changeSessionId()`. Replies come from `FormSupport.reply` as JSON `{ok, field, message, ...extra}`: a `field` puts the message under that
input, otherwise it goes in `.form-status`. 5 wrong current passwords lock changes for 15 minutes in
that session (429). Use the same token and JSON pattern for the other forms once they save.

**Show password**: every password input (login and the three profile ones) has a `.pass-toggle` eye
button right after it (`aria-controls` = the input id, `aria-pressed`, `data-show` / `data-hide` labels;
login's come from `login.password.show/hide`). Clicking it switches the input between `password` and
`text`; the handler is in both `script.js` and `dash.js`. Fields are switched back to hidden before
the login form submits and after a password change succeeds. Profile inputs sit in a `.pass-field`
wrapper; the styles are in `dash.css` and `login.css` (the same rules in both). `profile.css` styles only
`button[type="submit"]` in its forms, so other buttons there keep their own look.

**My students**: `/dashboard/counselor/students` lists the students whose `students.counselor_id` is the
counselor (`StudentDao.forCounselor`): name, id, gender, class, major, campus, enrollment year, phone/email links,
GPA (credit-weighted over graded enrollments, "—" if none), earned credits (grade point above 0) and leave status
(`.st-badge`: "On leave until <date>" for an approved request covering today, "N pending requests" linking to the
leave page, otherwise "No active leave"). `.st-stats` counts students, on leave today and pending requests.
`#stsearch` filters `.st-row`s by their text (`dash.js`), `.st-count` uses its `data-one` / `data-many`. Year and
credits columns (`.st-col-hide`) hide at 768px.

**PDF downloads**: both PDFs are built in the user's language with OpenPDF and the bundled Noto Sans SC (one
weight; `PdfSupport.bold` draws bold text with a thin stroke) and sent as `Content-Disposition: attachment`.
`/dashboard/timetable/download` (`.tt-download` on the student and teacher timetable pages) is an A4 landscape
grid (time + Mon–Sun × 5 slots) of `TimetableDao.forUser` for the latest semester; each class's split week ranges
are merged into one cell ("Weeks 1–9, 11–12"), students see the teacher's name, and a session longer than
2 periods spans rows. `/dashboard/leave/slip?id=` returns 404 unless the request is approved and the user is its
student or that student's counselor; it shows the student, leave and approval details. The `.lr-slip` link sits
in the approved `.lr-review` block on both leave pages (and is added by `dash.js` after a counselor approves,
from the table's `data-slip-url` / `data-slip-label`).

**Grades**: `/dashboard/grades` (students) follows the 教务 grade app: a `.gr-card` "Check grades" with the
`#grsemester` select (a GET form, submitted on change by `dash.js`; every semester the student has enrollments in,
newest first) and an "All semesters" line; a `.gr-card` for the chosen semester with `.gr-stats` (credits earned and
GPA); then one `.gr-course` card per graded course (score pill, `.gr-meta`: course code, type,
attribute, assessment, credits, hours, score, make-up exam, retake, grade point; `.failed` when the grade point is
0), or a `.gr-none` card ("No grades available for the <semester> semester."). Without `?semester=` (or with an
unknown one) it opens the newest semester that has grades. `GradeSummary` counts graded rows only: the GPA is the credit-weighted mean of the grade points (failed courses
included), credits earned are those with a grade point above 0. There is no weighted average score. Word grades show as 优/良/中/及格/不及格 (`gr.level.*`). Grade points always show one decimal (`GradeSummary.point`: 4.0, 0.0), GPAs and average grade points two (3.40), average scores one.

**Grade entry**: `/dashboard/teacher/grades` lists every class the teacher teaches (`#geclass`, a GET form
submitted on change, "course (code) · semester · N/M graded"); without `?class=` it opens the first class with
ungraded students. The class summary card shows semester, assessment, graded N/M, the average score and the
average grade point of the graded students (both refreshed from the save reply: `avgScore`, `avgPoint`, `graded`). Under it, `.ge-notice` warns that grades are final, then `.ge-table` has one
`.ge-row` per enrolled student (`data-id` = enrollment id): graded rows (`.done`) show the final score, grade point
and a "Final" badge; ungraded rows have a `.ge-score` input `score-<enrollment id>` (0–100, at most one decimal),
plus, for `assessment` (考查) courses, a `.ge-level` select `level-<id>` (优/良/中/及格/不及格) that disables the
input. `dash.js` checks each input, previews the grade point ((score − 50) / 10, 0 below 60; levels 4.5/3.5/2.5/1.5/0),
and `.ge-save` needs a second click ("Confirm: save N final grades", resets after 5 s). Empty boxes are left for
later. `GradeEntryServlet` re-checks everything (400 with `field` = the input id), and `GradeEntryDao.save` in one
transaction checks the class is the teacher's (404), writes only rows whose `score` is still NULL (others are
skipped; 409 if none were saved, also for SQLSTATE 45000), and adds a `grade` notification ("New grade posted",
link `/dashboard/grades`) per saved student. The reply has `saved` (ids) and `score-<id>` / `point-<id>`, which
turn the rows into final ones.

**Teacher pages**: `/dashboard/teacher/timetable` renders the teacher's current-semester `class_sessions` with the
same `tt-` markup and `dash.js` week logic as the student page (`data-semester-start` / `data-weeks` from `semesters`;
the toolbar is left out when the semester has no row, and the week script only runs when `.tt-toolbar` exists);
each `.tt-session` shows code, course, room, student count and the merged weeks, one element per week range.
`/dashboard/teacher/courses` (My Courses) has `.st-stats` (classes and students this semester, grades still to enter,
linking to Grade Entry), then the teacher's classes grouped by semester (newest first, "Current" on the latest), each
a `.co-card`: code, name, links to Grade Entry (`?class=`) and, for current classes, Exams; `gr-meta` (credits,
hours, type, assessment, students, graded, average score, average grade point); Schedule (day · periods · room ·
weeks) and Exams columns; and a `<details class="co-roster">` student list with each score and grade point.

## Working preferences

- When asked to fix one thing, change only that. Don't refactor or restyle nearby code.
- Never add comments to any code (CSS, JS, HTML, SQL, etc.). The codebase is kept comment-free.
