# Smart Society Management — Architecture Guide

## 1. Purpose

This document defines the technical architecture that all developers and Antigravity sessions must follow.

Do not introduce a new architecture without first evaluating compatibility with the existing implementation.

---

## 2. Architecture Principles

Use:
- Feature-oriented organization
- Separation of UI and business logic
- Reusable services
- Reusable widgets
- Typed models
- Centralized routing
- Centralized theme
- Firebase abstraction
- Role-based access

Avoid:
- Huge screen files
- Firebase queries scattered throughout widgets
- Duplicate service implementations
- Hard-coded IDs
- Hard-coded credentials
- Business logic directly inside UI widgets

---

## 3. Suggested Structure

```text
lib/
├── main.dart
├── core/
│   ├── constants/
│   ├── theme/
│   ├── routes/
│   ├── utils/
│   └── services/
├── models/
├── services/
│   ├── auth_service.dart
│   ├── firestore_service.dart
│   ├── storage_service.dart
│   └── notification_service.dart
├── providers/
├── screens/
│   ├── auth/
│   ├── admin/
│   └── resident/
└── widgets/
```

If the codebase already has a good structure, preserve it rather than forcing a rewrite.

---

## 4. Roles

```text
admin
resident
```

Every authenticated user should have a Firestore user document containing at minimum:
- role
- societyId

Residents should also have their flatId where applicable.

---

## 5. Data Isolation

Every society-owned entity must be associated with `societyId`.

Never query society data without applying the correct society context.

Typical relationships:

```text
User
 ├── societyId
 └── flatId

Flat
 ├── societyId
 └── residentId

Maintenance
 ├── societyId
 ├── residentId
 └── flatId

Complaint
 ├── societyId
 └── residentId

Notice
 └── societyId

Event
 └── societyId

AmenityRequest
 ├── societyId
 └── residentId
```

---

## 6. Firebase Collections

```text
societies/
users/
flats/
maintenance/
complaints/
notices/
events/
amenity_requests/
notifications/
activity_logs/
```

All relevant documents should use:
- societyId
- createdAt
- updatedAt

Use server timestamps.

---

## 7. Services

### AuthService
Responsibilities:
- Login
- Signup
- Logout
- Password reset
- Auth state

### FirestoreService
Responsibilities:
- CRUD
- Queries
- Streams
- Transactions where required

### StorageService
Responsibilities:
- Upload
- Delete where appropriate
- Download URLs
- Progress handling

### NotificationService
Responsibilities:
- FCM initialization
- Token handling
- Notification handling
- Local notifications if required

---

## 8. Security Model

UI restrictions are not security.

Firebase rules must enforce:
- Authentication
- Role
- Society ownership
- Resident ownership

Never allow unrestricted reads/writes.

---

## 9. State Management

Use the project's existing state-management solution if one is already established.

If starting from scratch, `provider` is acceptable for this project's complexity.

Do not introduce multiple state-management frameworks.

---

## 10. UI Components

Prefer reusable widgets for:
- Dashboard cards
- Status chips
- Search fields
- Filter controls
- Empty states
- Loading states
- Error states
- Primary buttons
- Form fields
- List cards
- Confirmation dialogs

---

## 11. Navigation

Centralize routes.

Auth flow:

```text
Splash
 ├── Login
 ├── Admin Dashboard
 └── Resident Dashboard
```

Do not rely only on hiding navigation items. Unauthorized routes must also be protected.

---

## 12. Firestore Query Rules

Avoid:
- Duplicate queries
- Unnecessary listeners
- Reading entire collections when only a subset is needed

Use:
- Proper filters
- Ordering
- Limits
- Pagination when appropriate
- Streams only where real-time updates matter

---

## 13. Image Storage

Recommended paths:

```text
societies/{societyId}/complaints/{complaintId}/...
societies/{societyId}/notices/{noticeId}/...
users/{userId}/profile/...
```

Storage rules must follow user/society permissions.

---

## 14. Error Handling

Convert Firebase/technical errors into user-friendly messages.

Do not expose:
- Stack traces
- Internal Firebase paths
- Permission internals
- Credentials
- Tokens

---

## 15. Git Rules

Use feature branches:

```text
feature/authentication
feature/maintenance
feature/complaints
feature/events
feature/amenities
fix/firebase-rules
```

Commit messages should be meaningful:

```text
feat: implement maintenance management
fix: prevent duplicate monthly maintenance
refactor: extract firestore service
docs: update project status
```

Do not commit:
- API keys that should be secret
- `.env` secrets
- Generated junk
- Temporary debug files

Firebase client configuration files may be required by the platform, but follow the project's intended Firebase setup and never add server credentials/service-account private keys to Git.

---

## 16. Developer Rule

Before changing code:
1. Pull latest code.
2. Inspect existing implementation.
3. Read project docs.
4. Identify dependencies.
5. Make the smallest clean change that solves the task.
6. Test.
7. Update documentation.
8. Commit.

