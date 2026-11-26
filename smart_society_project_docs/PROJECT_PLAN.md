# SocietyConnect Smart Society Management Application — Project Plan

## 1. Master AI Instruction

You are an expert Flutter, Dart, Firebase, UI/UX, mobile architecture, security, testing, and Git developer.

Build and maintain a production-quality Smart Society Management Application for residential societies using Flutter + Firebase.

**App Identity & Branding:**
- **App Name:** SocietyConnect
- **Logo:** Use the provided logo located in the `logo` folder (named `SocietyConnect`). Ensure this logo is integrated into the Splash Screen, Login Screen, and app headers/branding where appropriate.

The application must be:

- Professional and commercial-looking
- Secure
- Responsive
- Scalable
- Maintainable
- Suitable for an academic final-year project
- Suitable for real-world society management

IMPORTANT:

 1. Always inspect the existing code before changing anything.
 2. Read `ARCHITECTURE.md` and `CHANGELOG.md` before implementation.
 3. Never unnecessarily delete working code.
 4. Reuse existing services, models, widgets, routes, and architecture.
 5. Never duplicate an existing feature.
 6. Keep the project buildable after each task.
 7. Implement the requested work in one continuous run where practical. Do not use phases, phase gates, or stop after artificial milestones.
 8. Run analyzer/tests after meaningful changes.
 9. Update `CHANGELOG.md` after completing work.
10. Never expose secrets or credentials.

- Do not add image upload or image attachment features, and do not use Firebase Storage; use text, initials, and icons instead. (Note: Using the static SocietyConnect logo asset from the local `logo` folder is required and exempt from this rule).

## 2. Project Objective

Create a centralized digital platform for residential society management under the name **SocietyConnect**.

Replace:

- Manual registers
- Paper notices
- Spreadsheet maintenance tracking
- Manual complaint handling
- Manual event communication
- Manual amenity/party-hall booking

with a centralized mobile application.

The application has two roles:

1. Admin
2. Resident

Both use the same Firebase backend with strict role-based and society-based data isolation.

## 3. Technology Stack

### Frontend

- Flutter
- Dart
- Material 3
- Responsive UI

### Backend

- Firebase Authentication
- Cloud Firestore
- Firebase Cloud Messaging

### Recommended packages

Use stable packages only when required:

- firebase_core
- firebase_auth
- cloud_firestore
- firebase_messaging
- intl
- provider
- shared_preferences
- flutter_local_notifications
- uuid

Do not add unnecessary dependencies.

## 4. Main Features

### Authentication and Email Verification

- Splash screen (displaying the SocietyConnect logo) and login
- Admin registration and resident registration using Society ID
- Email verification link sent to the registered email address
- Create the Firestore user profile only after the user verifies their email
- Block login and role-based access until email verification is confirmed
- Resend verification email and provide a clear "I've verified" / refresh verification action
- Forgot password using Firebase Authentication password-reset email
- Logout, authentication-state handling, and role-based routing

**Required registration flow**

1. Collect and validate the registration details. For residents, validate the Society ID and any required flat/role eligibility.
2. Create the Firebase Authentication account and send a verification email. Show a clear message telling the user to open the email and tap the verification link.
3. Do not create the Firestore user profile, assign the user an application role, or grant access to society data before email verification is confirmed.
4. After the user follows the email link, refresh/reload the Firebase Authentication user and confirm `emailVerified == true`. Handle returning to the app by checking verification status when the app resumes and when the user taps a refresh/verification button.
5. Only after verification succeeds, create the Firestore user profile with the validated role and `societyId` (and required resident/flat details), then allow the user to continue to login.
6. If verification has not happened, keep access blocked, offer to resend the email, and do not create the profile. Handle expired links, duplicate email addresses, cancellation, and network errors with clear messages.

**Required forgot-password flow**

- On the login screen, provide a "Forgot Password?" link.
- Ask for the registered email and use Firebase Authentication to send the password-reset email.
- Show a neutral confirmation message and handle invalid email, unknown account, rate-limit, and network errors safely.
- Do not change passwords directly in Firestore or store passwords in application documents.

**Security requirements**

- Enforce email verification in the app's authentication flow before profile creation or protected access.
- Never trust a client-only screen check as the sole security control; apply appropriate Firebase security rules and trusted backend validation where needed.
- Do not allow an unverified user to create or modify a profile or access Admin/Resident features.
- Keep role assignment and society membership validation secure; users must not be able to register themselves as an Admin for an existing society or bypass resident Society ID checks.

### Admin

- Dashboard
- Society management
- Resident management
- Flat management
- Maintenance management
- Notice management
- Complaint management
- Event/meeting management
- Amenity/party-hall requests
- Analytics
- Activity log
- Profile
- Settings

### Resident

- Dashboard
- Maintenance dues/history
- Notices
- Complaints
- Events/meetings
- Amenity requests
- Profile
- Notifications

## 5. Admin Dashboard

Display:

- Total Residents
- Total Flats
- Occupied Flats
- Vacant Flats
- Paid Maintenance
- Pending Maintenance
- Open Complaints
- Resolved Complaints
- Upcoming Events
- Pending Amenity Requests
- Recent Activity

Use real Firestore data and avoid unnecessary reads.

## 6. Society Management

Society fields:

- societyId
- name
- address
- contactNumber
- email
- createdAt
- updatedAt

Each admin must only manage their own society.

## 7. Flat Management

Admin can:

- Add
- Edit
- View
- Assign resident
- Unassign resident
- Deactivate
- Search
- Filter

Flat fields:

- flatId
- societyId
- flatNumber
- floor
- block
- residentId
- status
- createdAt
- updatedAt

Status:

- Occupied
- Vacant

Prevent duplicate flat numbers within a society.

## 8. Resident Management

Admin can:

- View
- Search
- Filter
- View profile
- Edit allowed information
- Assign flat
- Deactivate

Resident information:

- Name
- Email
- Mobile
- Flat
- Society
- Maintenance status
- Complaint history
- Amenity requests

## 9. Maintenance

Admin:

- Set monthly maintenance
- Generate monthly dues
- View paid residents
- View pending residents
- Search
- Filter by month
- Filter Paid/Pending
- Sort by highest pending amount
- Update payment status
- View history

Resident:

- View current dues
- View pending amount
- View payment status
- View payment history
- View payment date
- View payment method

Maintenance fields:

- maintenanceId
- societyId
- residentId
- flatId
- flatNumber
- month
- year
- amount
- status
- paymentDate
- paymentMethod
- createdAt
- updatedAt

Prevent duplicate records for the same society + resident/flat + month + year.

## 10. Notices

Admin:

- Create
- Edit
- Delete/deactivate
- Category
- Publish

Categories:

- General
- Maintenance
- Emergency
- Meeting
- Event
- Important

Resident:

- View
- Search
- Filter
- Details

## 11. Complaints

Resident:

- Create complaint
- Title
- Description
- Category
- Track status
- View admin response
- View history

Categories:

- Water
- Electricity
- Security
- Cleaning
- Maintenance
- Parking
- Other

Statuses:

- Pending
- In Progress
- Resolved
- Rejected

Admin:

- View
- Search
- Filter
- Open details
- Change status
- Add response

## 12. Events and Meetings

Admin:

- Create
- Edit
- Delete
- Date
- Time
- Location
- Category

Resident:

- View upcoming events
- View details

Validate date/time.

## 13. Amenity / Party Hall Requests

Amenities:

- Party Hall
- Community Hall
- Garden
- Club House
- Other

Request fields:

- requestId
- societyId
- residentId
- amenity
- date
- startTime
- endTime
- purpose
- notes
- status
- adminResponse
- createdAt
- updatedAt

Statuses:

- Pending
- Approved
- Rejected
- Completed

Admin can approve/reject/complete requests.

IMPORTANT:
Prevent overlapping bookings for the same amenity.

## 14. Resident Dashboard

Display:

- Welcome message
- Maintenance status
- Pending dues
- Active complaints
- Latest notices
- Upcoming events
- Amenity request status

Resident bottom navigation:

- Home
- Maintenance
- Complaints
- Notices
- Profile

Events and amenity requests can be accessed from Home or appropriate feature screens.

## 15. Notifications

Use Firebase Cloud Messaging where practical.

Notify residents for:

- New notices
- Maintenance dues
- Complaint status changes
- New events
- Amenity approval
- Amenity rejection

Notification fields:

- notificationId
- userId
- societyId
- title
- message
- type
- isRead
- createdAt

## 16. Firestore Collections

Use:

- societies/{societyId}
- users/{userId}
- flats/{flatId}
- maintenance/{maintenanceId}
- complaints/{complaintId}
- notices/{noticeId}
- events/{eventId}
- amenity_requests/{requestId}
- notifications/{notificationId}
- activity_logs/{activityId}

Relevant documents should contain:

- societyId
- createdAt
- updatedAt

Use server timestamps.

## 17. Security

Never use insecure rules such as:
`allow read, write: if true;`

Admin:

- Access only own society

Resident:

- Access only permitted data
- Read society notices/events
- Read own maintenance
- Create/read own complaints
- Read own requests
- Update only permitted profile fields

Residents must not:

- Read another resident's private data
- Modify maintenance
- Modify notices
- Modify events
- Modify other users
- Access another society

Security must be enforced in Firebase rules, not only Flutter.

## 18. UI/UX

Build a professional commercial UI.

Use:

- Material 3
- Blue/indigo primary theme
- Clean typography
- Rounded cards
- Consistent spacing
- Clear icons
- Good contrast
- Responsive layouts
- Professional loading/empty/error states

**Branding:** Explicitly use the name "SocietyConnect" and integrate the provided `SocietyConnect` logo from the local `logo` folder across the Splash Screen, Login Screen, and app headers where applicable.

Avoid:

- Excessive gradients
- Excessive animations
- Clutter
- Inconsistent spacing
- Tiny text
- Default-looking college-project UI

Status colors:

- Paid = Green
- Pending = Orange
- Resolved = Green
- In Progress = Blue
- Rejected = Red
- Approved = Green

Support light and dark mode.
Persist theme preference.

## 19. Validation and Error Handling

Validate:

- Required fields
- Email
- Password
- Confirm password
- Mobile
- Society ID
- Flat number
- Dates
- Times
- Booking conflicts

Handle:

- No internet
- Firebase errors
- Auth errors
- Permission errors
- Missing documents
- Empty data

Show user-friendly messages, not raw Firebase exceptions.

## 20. Performance

Optimize:

- Firestore reads
- Streams
- List rendering
- Widget rebuilds
- Navigation

Use:

- Pagination where needed
- Lazy lists
- const widgets
- Debounced search
- Efficient queries
- Proper disposal

## 21. Responsive Design

Support:

- Android phones
- iPhones
- Tablets
- Different screen sizes

Use:

- MediaQuery
- LayoutBuilder
- Flexible
- Expanded
- SafeArea
- SingleChildScrollView
- ListView

No overflow errors.

## 22. No Image Uploads or Firebase Storage

Do not implement user image uploads, user image attachments, profile photos, notice images, or complaint images. Use text, initials, icons, and status indicators instead. Do not configure or use Firebase Storage, image_picker, cached_network_image, or any image-upload dependency. Keep all society data in Firebase Authentication and Cloud Firestore, with Firebase Cloud Messaging for notifications. *(Note: Using the static SocietyConnect logo asset from the local `logo` folder for app branding is required and exempt from this rule).*

## 23. Analytics

Admin analytics:

- Total residents
- Total flats
- Occupancy
- Paid/pending maintenance
- Open/resolved complaints
- Upcoming events
- Pending requests

Optional simple charts:

- Paid vs Pending Maintenance
- Complaint Status
- Occupied vs Vacant Flats

Do not create unnecessarily complex analytics.

## 24. Activity Log

Track:

- Resident registration
- Flat assignment
- Maintenance update
- Notice publication
- Complaint status change
- Event creation
- Amenity approval/rejection

Activity fields:

- activityId
- societyId
- userId
- action
- description
- createdAt

## 25. Sample Data

Provide a development/demo mechanism for:

- Society
- Admin
- Residents
- Flats
- Maintenance
- Notices
- Complaints
- Events
- Amenity requests

Do not hard-code fake production users.

## 26. Continuous Implementation Workflow

Do not divide implementation into phases or require phase-by-phase approval. Work continuously and complete as much of the requested project or feature as safely possible in one run.

1. Inspect the existing project, dependencies, Firebase setup, screens, services, models, routes, tests, and reusable code.
2. Read `ARCHITECTURE.md` and `CHANGELOG.md` if present. Treat the changelog as the single source of truth for progress.
3. Identify what is already implemented, what is incomplete, and the highest-priority next task. Avoid duplicating working features.
4. Follow the existing architecture and implement tasks in a sensible dependency order, without phase labels or artificial stopping points.
5. Keep existing functionality working. Make related changes together and do not stop for approval unless a decision, credential, or destructive action genuinely requires user input.
6. Run `flutter pub get` when dependencies change, then run `flutter analyze` and relevant tests. Fix issues caused by your changes and verify the app/build where feasible.
7. If the full task cannot be completed in one run, finish the largest safe, working portion and clearly record the exact continuation point.
8. At the end of every work session, update only `CHANGELOG.md` using the format below.

**Required `CHANGELOG.md` format**

- **Last updated:** date
- **Completed:** concrete features/files finished in this session
- **Current state:** what works now and any important setup requirements
- **In progress:** work started but not finished
- **Known issues:** errors, missing configuration, or tests that still fail
- **Next steps:** the exact next task(s), in priority order, with enough detail for another developer or AI to continue
- **Verification:** commands run and their actual results

Keep entries concise and append a dated session entry instead of deleting useful history. Do not claim a test or build passed unless it was actually run successfully. If no work was completed, record the blocker and the next action.

## 27. Antigravity Session Instruction

At the beginning of every session, read `ARCHITECTURE.md` and `CHANGELOG.md`, inspect the current Git working tree and existing implementation, and verify the latest repository state when appropriate. Use `CHANGELOG.md` to determine what is already complete, what remains unfinished, any known blockers, and the exact next task. Continue from that point; do not restart completed work, duplicate features, or introduce phase-wise implementation.

For any command such as **“continue,” “continue the project,” or “do the next task”**:

1. Read the latest changelog entry and inspect the actual code to verify it.
2. Resume from the recorded next step or unfinished task.
3. Implement as much as possible in one continuous run, following dependencies and preserving working features.
4. Run `flutter analyze` and relevant tests; fix issues introduced by your changes.
5. Update only `CHANGELOG.md` with completed work, current state, unfinished work, blockers, verification results, and the exact next step.
6. Leave the repository in a clear, working state. Never report unverified work as complete.

For a specific task, implement it directly after inspecting existing code. Reuse existing architecture, services, models, widgets, and routes. Do not rebuild existing functionality unnecessarily. Do not stop at artificial milestones or ask for approval between routine implementation steps.

## 28. Final Acceptance Criteria

The application must:

- Compile successfully
- Pass flutter analyze
- Have working authentication with email verification
- Send registration verification links to email and create the Firestore profile only after verification succeeds
- Prevent unverified users from logging in to protected features
- Have a working forgot-password email flow
- Have Admin Panel
- Have Resident Portal
- Have role-based routing
- Have society-level isolation
- Have Firestore CRUD
- Have notifications where configured
- Have maintenance
- Have resident management
- Have flat management
- Have notices
- Have complaints
- Have events
- Have amenity requests
- Have booking conflict detection
- Have analytics
- Have activity logs
- Have secure Firebase rules
- Have responsive UI incorporating the SocietyConnect branding and logo
- Have dark mode
- Have validation
- Have loading states
- Have empty states
- Have error handling
- Have no major overflow
- Have no major broken navigation
- Have no major placeholder features

The final product must be a polished, secure, responsive Flutter + Firebase Smart Society Management Application.