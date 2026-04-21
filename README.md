# Competitive Programming Helper

Competitive Programming Helper is a SwiftUI iOS app for Codeforces-focused practice. It combines Firebase-backed user accounts with public Codeforces data, cp-algorithms content, contest reminders, saved practice problems, and an in-app Gemini-powered coaching workspace.

The app source lives in `CPHelper/`, and the Xcode project is `CPHelper.xcodeproj`.

## What The App Does

- Authenticates users with Firebase email/password sign-in.
- Stores a user profile with full name, mobile number, university, profile image URL, primary Codeforces handle, friend handles, saved problems, and contest registration state.
- Analyzes any public Codeforces handle using `user.info`, `user.rating`, and `user.status`.
- Shows a home dashboard for the signed-in user's primary handle and next upcoming contest.
- Tracks upcoming Codeforces contests and schedules local reminders.
- Generates practice suggestions from the public Codeforces problemset using the user's rating history and weak tags.
- Lets users save Codeforces problems to a ToDo list and open problem/editorial pages.
- Loads cp-algorithms tutorials, extracts a cleaner summary/detail view, and opens original articles when needed.
- Provides a Gemini-based "CP Coach" chat workspace that can answer competitive programming questions and deep-link into app screens.
- Works with cache and bundled fallback data when live network data is unavailable.

## Main User Flow

1. Launch the app.
2. `ContentView` decides between bootstrapping, auth, or the signed-in shell.
3. After sign-in, `MainShellView` opens a three-tab interface:
   - `Home`
   - `Toolkit`
   - `Profile`
4. Floating actions open:
   - `NotificationCenterView`
   - `ChatbotWorkspaceView`

## Tabs And Features

### Home

- Greets the signed-in user.
- Shows the primary Codeforces handle summary if one is set.
- Lets the user save a primary handle if missing.
- Loads handle analysis charts and summary stats.
- Highlights the next upcoming contest and links to the contest calendar.

### Toolkit

- Analyze any public Codeforces handle.
- Browse friend handles and inspect each friend's dashboard.
- Open the contest calendar and registration tracking.
- Get suggested problems by rating band and weak tags.
- Manage a ToDo list of saved Codeforces problems.
- Browse a static rating roadmap.
- Read cp-algorithms tutorials inside the app.

### Profile

- Displays account details and primary handle.
- Opens a profile editor sheet.
- Supports sign out.

## Architecture Overview

The app follows a straightforward SwiftUI + observable store structure:

- `CompetitiveProgrammingHelperApp`
  Creates and injects the main environment objects.
- `SessionStore`
  Owns authenticated user state and profile mutations.
- `AppRouter`
  Manages tab selection and in-app navigation destinations.
- `TutorialLibraryStore`
  Loads tutorial catalog data and exposes matching/search helpers.
- `ContestCenterStore`
  Loads upcoming contests, builds reminder feeds, tracks unread reminders, and schedules notifications.

Feature views stay fairly thin and delegate network, caching, and parsing work to service actors.

## Services And Responsibilities

- `FirebaseAccountStore`
  Handles Firebase Auth sign-in/sign-up, Firestore profile persistence, profile mutations, and local cache fallback.
- `CodeforcesAnalysisService`
  Builds `HandleAnalysis` objects from Codeforces APIs and caches results in memory, on disk, and via bundled fallback JSON.
- `CodeforcesContestService`
  Loads upcoming Codeforces contests with disk and bundle fallback support.
- `CodeforcesProblemCatalogService`
  Loads the Codeforces problemset, parses Codeforces problem URLs, and resolves problems for ToDo saving.
- `CodeforcesEditorialService`
  Scrapes a Codeforces problem page to find its linked tutorial/editorial URL.
- `TutorialCatalogService`
  Scrapes the cp-algorithms catalog, downloads markdown detail pages, and extracts overviews, section headings, and related links.
- `GeminiChatService`
  Sends structured coaching context plus recent conversation history to Gemini `gemini-2.5-flash`.
- `CodeforcesRequestGate`
  Serializes Codeforces requests with a minimum delay to avoid hammering the API.
- `ProfileCacheStore`
  Stores cached user profiles under the app support directory.

## Data Sources

- Firebase Authentication for email/password auth.
- Cloud Firestore for user profiles.
- Codeforces public API for:
  - user info
  - rating history
  - submission history
  - contest list
  - problemset
- Codeforces HTML pages for editorial discovery.
- cp-algorithms website and markdown source for tutorial catalog/detail extraction.
- Gemini API for the coaching assistant.

## Caching And Offline Fallbacks

Several features are resilient to network failures:

- Profile data is cached locally after Firebase reads/writes.
- Handle analysis is cached in memory and on disk, and can fall back to `Resources/handle_analysis_fallbacks.json`.
- Contest data can fall back to `Resources/contest_fallbacks.json`.
- Problem catalog data can fall back to `Resources/problemset_fallback.json`.
- Tutorial list/detail data can fall back to:
  - `Resources/tutorials.json`
  - `Resources/tutorial_detail_fallbacks.json`

From source inspection, the main cache windows are:

- Handle analysis: 6 hours
- Problemset: 12 hours
- Tutorials: 24 hours
- Contests: 30 minutes

## Notifications

Contest reminders are managed by `ContestCenterStore` and use `UserNotifications`.

The app prepares reminder items for:

- 24 hours before a contest
- 3 hours before a contest if the user's primary handle is not marked registered
- 1 hour before a contest

Unread reminder state is tracked locally with `UserDefaults`.

## Practice Recommendation Logic

`SuggestedProblemsViewModel` builds recommendations by:

- loading the primary handle analysis
- loading the Codeforces problem catalog
- choosing a rating window near the user's peak/current strength
- excluding already solved problems
- excluding special or interactive tasks
- generating weak-tag suggestions from low-acceptance topics with enough attempts

## Chat / CP Coach

The chat workspace is not a general-purpose assistant. The system prompt explicitly keeps it focused on:

- competitive programming
- Codeforces handle analysis
- contest preparation
- DSA/topic learning
- roadmap planning
- problem hints and approach discussion

The chat layer can also detect route intents and open:

- a handle analysis screen
- a tutorial
- the contest calendar

## Project Structure

```text
CPHelper/
├── AppDelegate.swift
├── AppRouter.swift
├── CompetitiveProgrammingHelperApp.swift
├── ContentView.swift
├── HomeView.swift
├── PracticeListView.swift
├── TutorialDetailView.swift
├── TutorialListView.swift
├── Models/
├── Core/
├── Resources/
├── Services/
├── ViewModels/
└── Views/
```

Key folders:

- `Models/` domain models for profiles, contests, problems, chat, tutorials, and analysis
- `Services/` Firebase, Codeforces, tutorial, editorial, cache, and Gemini integrations
- `ViewModels/` state and feature-specific orchestration
- `Views/` feature UI grouped by area like auth, toolkit, profile, analysis, contests, notifications, and shared UI
- `Resources/` bundled fallback JSON used when live sources are unavailable

## External Dependencies

The project uses Apple frameworks plus Swift Package Manager dependencies.

- SwiftUI
- Charts
- UserNotifications
- Firebase iOS SDK

`Package.resolved` currently pins Firebase iOS SDK `11.15.0` and related Google packages.

## Configuration

### Required Files

- `CPHelper/GoogleService-Info.plist`
  Firebase app configuration used at startup.
- `CPHelper/LocalSecrets.plist`
  Optional local secret file for Gemini.
- `CPHelper/LocalSecrets.plist.example`
  Template showing the expected `GEMINI_API_KEY` entry.

### Gemini API Key Resolution Order

`GoogleServiceConfiguration` looks for a Gemini key in this order:

1. `GEMINI_API_KEY` from the Xcode scheme environment
2. `LocalSecrets.plist` value for `GEMINI_API_KEY`
3. `GoogleService-Info.plist` value for `GEMINI_API_KEY`
4. `GoogleService-Info.plist` value for `API_KEY`

### Firebase Expectations

For sign-in to work correctly, the Firebase project should have:

- Email/Password authentication enabled
- Firestore available for the `users` collection
- A `GoogleService-Info.plist` that matches the bundle identifier configured in the project

## Getting Started

1. Open `CPHelper.xcodeproj` in Xcode.
2. Confirm `GoogleService-Info.plist` points at the Firebase project you want to use.
3. Create `CPHelper/LocalSecrets.plist` from `CPHelper/LocalSecrets.plist.example` if you want CP Coach enabled with a dedicated Gemini key.
4. In Firebase Console, enable Email/Password sign-in.
5. Build and run the `CPHelper` target on a simulator or device.
6. Sign up for an account, add a primary handle, and explore the Toolkit features.

## Notes And Caveats

- The actual git repository root is this folder: `Lalon/CPHelper`.
- The project currently has one app target, `CPHelper`.
- No unit-test or UI-test target is present in the repository right now.
- `CPHelper-Info.plist` disables `FirebaseAppDelegateProxyEnabled`, so Firebase startup is handled manually in `AppDelegate`.
- The Xcode project currently sets `IPHONEOS_DEPLOYMENT_TARGET = 26.4`; verify that this matches your local Xcode/device support before building.

## Useful Entry Points

- `CPHelper/CompetitiveProgrammingHelperApp.swift`
- `CPHelper/ContentView.swift`
- `CPHelper/Views/MainShellView.swift`
- `CPHelper/Services/FirebaseAccountStore.swift`
- `CPHelper/Services/CodeforcesAnalysisService.swift`
- `CPHelper/Services/ContestCenterStore.swift`
- `CPHelper/Services/CodeforcesProblemCatalogService.swift`
- `CPHelper/Services/TutorialCatalogService.swift`
- `CPHelper/Services/GeminiChatService.swift`

