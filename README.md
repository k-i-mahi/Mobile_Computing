<p align="center">
  <img src="https://img.shields.io/badge/Platform-iOS_17+-000000?style=for-the-badge&logo=apple&logoColor=white" />
  <img src="https://img.shields.io/badge/SwiftUI-5.0-0071E3?style=for-the-badge&logo=swift&logoColor=white" />
  <img src="https://img.shields.io/badge/Firebase-Auth_%7C_Firestore-FFCA28?style=for-the-badge&logo=firebase&logoColor=black" />
  <img src="https://img.shields.io/badge/Architecture-MVVM-8E44AD?style=for-the-badge" />
  <img src="https://img.shields.io/badge/License-Academic-2ECC71?style=for-the-badge" />
</p>

<h1 align="center">📱 CampusConnect</h1>
<p align="center"><strong>A full-featured campus event management &amp; news platform for iOS</strong></p>
<p align="center"><em>Built with SwiftUI · Firebase · MVVM · NewsAPI</em></p>

---

## 📋 Table of Contents

- [Overview](#-overview)
- [Features](#-features)
- [Screenshots](#-screenshots)
- [Architecture](#-architecture)
- [Tech Stack](#-tech-stack)
- [Project Structure](#-project-structure)
- [Getting Started](#-getting-started)
- [Firebase Setup](#-firebase-setup)
- [Configuration](#-configuration)
- [Team & Contributions](#-team--contributions)
- [Git Workflow](#-git-workflow)
- [Dependencies](#-dependencies)
- [License](#-license)

---

## 🎯 Overview

**CampusConnect** is a native iOS application that helps university students discover campus events, manage RSVPs, read curated news, and connect with event organizers — all in one polished, modern interface.

The app demonstrates professional-grade iOS development practices including real-time Firestore synchronization, actor-based network services, custom animations, and a comprehensive design system.

---

## ✨ Features

### 🔐 Authentication & Profile
- Email/password sign-up and sign-in via **Firebase Authentication**
- Animated splash screen with auth-state routing
- Editable user profile with avatar, bio, and interests
- Theme switching (System / Light / Dark) persisted via `@AppStorage`
- Input validation with real-time feedback

### 📅 Events System
- **Firestore-backed** event creation, editing, and deletion
- Real-time event list with **Firestore snapshot listeners**
- **RSVP system** with subcollection-based tracking (`/events/{id}/rsvps`)
- Category-based filtering (Academic, Sports, Cultural, Tech, Social, Workshop)
- Full-text search across title, venue, and tags
- **Monthly calendar view** with event-day highlighting
- Seat availability scoring with animated counters
- Organizer profile cards
- Local JSON event dataset for offline/demo browsing

### 📰 News Feed
- Live news via **NewsAPI** integration
- **Actor-based** REST client with async/await
- 5-minute response cache to minimize API calls
- Pull-to-refresh with loading states
- Article detail sheet with Safari link-out

### 🎨 Design System
- Comprehensive color tokens and category-specific gradients
- Reusable components: `EventCardView`, `CategoryBadgeView`, `SeatCounterView`
- Shared UI states: `LoadingView`, `ErrorView`, `EmptyStateView`, `SearchBar`
- Custom view modifiers: card style, shimmer loading, staggered animations
- Haptic feedback manager for tactile interactions

---

## 📸 Screenshots

> *Screenshots can be added here after running the app on a simulator or device.*

| Dashboard | Event List | Event Detail | News Feed | Profile |
|:---------:|:----------:|:------------:|:---------:|:-------:|
| — | — | — | — | — |

---

## 🏗 Architecture

CampusConnect follows the **MVVM (Model-View-ViewModel)** architecture pattern:

```
┌─────────────────────────────────────────────────┐
│                    Views (UI)                    │
│  SwiftUI views observe ViewModels reactively     │
├─────────────────────────────────────────────────┤
│                  ViewModels                      │
│  @Published state · Business logic · Data flow   │
├─────────────────────────────────────────────────┤
│              Models + Services                   │
│  Codable structs · Firebase · NewsAPI · RSVP     │
├─────────────────────────────────────────────────┤
│                 Utilities                        │
│  Constants · Extensions · Formatters · Helpers   │
└─────────────────────────────────────────────────┘
```

**Key Patterns:**
- `@StateObject` / `@EnvironmentObject` for dependency injection
- `@Published` properties for reactive UI updates
- Actor isolation for thread-safe network services
- Firestore snapshot listeners for real-time data sync
- Codable protocol for JSON ↔ model serialization

---

## 🛠 Tech Stack

| Technology | Purpose |
|------------|---------|
| **SwiftUI** | Declarative UI framework (iOS 17+) |
| **Firebase Auth** | Email/password authentication |
| **Cloud Firestore** | Real-time NoSQL database for events, RSVPs, profiles |
| **NewsAPI** | External REST API for campus news |
| **Swift Concurrency** | async/await, actors for network layer |
| **Combine** | Reactive data binding (via `@Published`) |
| **Xcode 15+** | IDE and build system |

---

## 📁 Project Structure

```
CampusConnect/
├── App/
│   └── CampusConnectApp.swift          # App entry point, Firebase init, environment injection
│
├── Models/
│   ├── Event.swift                     # Local JSON event data model
│   ├── FirestoreEvent.swift            # Firestore event data model
│   ├── NewsArticle.swift               # News article data model
│   ├── Organizer.swift                 # Organizer data model
│   └── UserProfile.swift              # User profile data model
│
├── ViewModels/
│   ├── AuthViewModel.swift             # Firebase Auth sign-up/sign-in/sign-out
│   ├── EventJSONViewModel.swift        # Local JSON event loading & filtering
│   ├── FirestoreEventManager.swift     # Firestore CRUD + real-time listeners
│   ├── NewsViewModel.swift             # News fetching, caching, state management
│   ├── ProfileViewModel.swift          # User profile Firestore read/write
│   ├── SeatScoreViewModel.swift        # Seat availability scoring logic
│   └── ThemeManager.swift              # Theme persistence (system/light/dark)
│
├── Views/
│   ├── Auth/
│   │   ├── AuthRouterView.swift        # Splash → login/dashboard routing
│   │   └── LoginView.swift             # Login & registration UI
│   ├── Calendar/
│   │   └── CalendarView.swift          # Monthly calendar with event markers
│   ├── Components/
│   │   ├── CategoryBadgeView.swift     # Category badge (pill/chip/label styles)
│   │   ├── EventCardView.swift         # Reusable event card component
│   │   ├── SeatCounterView.swift       # Animated seat availability indicator
│   │   └── SharedComponents.swift      # LoadingView, ErrorView, EmptyState, SearchBar
│   ├── Events/
│   │   ├── CreateEventView.swift       # New event form (Firestore)
│   │   ├── EditEventView.swift         # Edit existing event form
│   │   ├── EventDetailView.swift       # Full event detail with RSVP
│   │   ├── EventFilterView.swift       # Category filter sheet
│   │   ├── EventListView.swift         # Explore tab — searchable event list
│   │   └── MyEventsView.swift          # User's own Firestore events
│   ├── Home/
│   │   └── DashboardView.swift         # Main tab bar container
│   ├── News/
│   │   └── NewsListView.swift          # News feed with pull-to-refresh
│   ├── Organizer/
│   │   └── OrganizerProfileView.swift  # Organizer detail card
│   ├── Profile/
│   │   └── ProfileView.swift           # Profile display & inline editing
│   └── Settings/
│       └── SettingsView.swift          # Theme selector, about section
│
├── Services/
│   ├── NewsAPIService.swift            # Actor-based REST client with cache
│   ├── RSVPManager.swift               # RSVP check/toggle/count via Firestore
│   └── ValidationService.swift         # Input validation for forms
│
├── Utilities/
│   ├── Bundle+Decode.swift             # Generic JSON decoding from bundle
│   ├── Constants.swift                 # Design tokens, colors, gradients
│   ├── DateFormatterHelper.swift       # Date parsing & formatting utilities
│   └── ViewExtensions.swift            # CardModifier, ShimmerModifier, HapticManager
│
└── Resources/
    └── events.json                     # Sample event dataset (10 events)

Root Files:
├── .gitignore                          # Git ignore rules
├── DEPENDENCIES.md                     # Swift package dependency guide
├── TEAM_DIVISION.md                    # Detailed team work division
├── firestore.rules                     # Firestore security rules
└── README.md                           # This file
```

**Total: 42 source files across 5 layers**

---

## 🚀 Getting Started

### Prerequisites

| Requirement | Version |
|-------------|---------|
| macOS | 14.0+ (Sonoma) |
| Xcode | 15.0+ |
| iOS Deployment Target | 17.0+ |
| Swift | 5.9+ |
| Firebase Account | Free tier works |
| NewsAPI Key | Free at [newsapi.org](https://newsapi.org) |

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/k-i-mahi/Mobile_Computing.git
   cd Mobile_Computing
   ```

2. **Open in Xcode**
   ```bash
   open CampusConnect.xcodeproj
   ```
   > Or open Xcode → File → Open → select the project folder.

3. **Add Firebase SDK**
   - Go to **File → Add Package Dependencies**
   - Enter URL: `https://github.com/firebase/firebase-ios-sdk`
   - Version rule: **Up to Next Major** from `10.0.0`
   - Select products: `FirebaseAuth`, `FirebaseFirestore`, `FirebaseFirestoreSwift`

4. **Configure Firebase** (see [Firebase Setup](#-firebase-setup) below)

5. **Add NewsAPI Key**
   - Open `CampusConnect/Services/NewsAPIService.swift`
   - Replace the placeholder API key with your own from [newsapi.org](https://newsapi.org)

6. **Build & Run**
   - Select an iOS 17+ simulator (iPhone 15 recommended)
   - Press `⌘R` to build and run

---

## 🔥 Firebase Setup

1. Go to [Firebase Console](https://console.firebase.google.com) and create a new project
2. Add an **iOS app** — bundle ID must match your Xcode project
3. Download `GoogleService-Info.plist`
4. Drag it into the Xcode project root (check **"Copy items if needed"**)
5. Enable **Email/Password** sign-in under **Authentication → Sign-in method**
6. Create a **Firestore database** (start in test mode)
7. Apply security rules from `firestore.rules`:
   - Go to **Firestore → Rules** tab in Firebase Console
   - Paste the contents of `firestore.rules` and publish

### Firestore Collections

| Collection | Document Fields | Description |
|------------|----------------|-------------|
| `users/{uid}` | displayName, email, bio, avatarURL, interests, joinedDate | User profiles |
| `events/{id}` | title, description, date, venue, category, organizer, totalSeats, tags, creatorUID | Events |
| `events/{id}/rsvps/{uid}` | userID, timestamp | RSVP records |

---

## ⚙️ Configuration

### NewsAPI
The app uses [NewsAPI.org](https://newsapi.org) for the news feed. Get a free API key and update it in:
```
CampusConnect/Services/NewsAPIService.swift
```

### Firestore Rules
Security rules are defined in `firestore.rules` at the project root. They enforce:
- Authenticated read/write for user profiles (own data only)
- Authenticated read for all events; write restricted to event creator
- RSVP subcollection access for authenticated users

---

## 👥 Team & Contributions

This project was developed collaboratively by a team of three, each owning an end-to-end vertical slice:

| Member | GitHub | Role | Files | Lines |
|--------|--------|------|:-----:|:-----:|
| **M** | [@k-i-mahi](https://github.com/k-i-mahi) | Authentication & User Profile | 11 | 1,126 |
| **S** | [@sa-hcc5142](https://github.com/sa-hcc5142) | Events System | 17 | 2,108 |
| **A** | [@deb-nath](https://github.com/deb-nath) | News & Shared UI Components | 14 | 1,564 |

### Contribution Breakdown

#### M — Authentication & User Profile
> Firebase Auth flow, user profile management, settings, theme switching, security rules

- `AuthViewModel`, `ProfileViewModel`, `ThemeManager`
- `UserProfile` model, `ValidationService`
- `LoginView`, `AuthRouterView`, `ProfileView`, `SettingsView`
- `CampusConnectApp` (app entry), `firestore.rules`

#### S — Events System
> Firestore event CRUD, RSVP management, calendar, filters, search, seat scoring

- `FirestoreEventManager`, `EventJSONViewModel`, `SeatScoreViewModel`
- `FirestoreEvent`, `Event`, `Organizer` models, `RSVPManager`
- `EventListView`, `EventDetailView`, `EventFilterView`, `CreateEventView`, `EditEventView`, `MyEventsView`
- `CalendarView`, `OrganizerProfileView`, `DashboardView`
- `events.json`

#### A — News & Shared UI Components
> NewsAPI integration, reusable components, design system, utilities, documentation

- `NewsViewModel`, `NewsArticle` model, `NewsAPIService`
- `NewsListView`, `EventCardView`, `CategoryBadgeView`, `SeatCounterView`, `SharedComponents`
- `Constants`, `DateFormatterHelper`, `Bundle+Decode`, `ViewExtensions`
- `README.md`, `DEPENDENCIES.md`

> 📄 See **[TEAM_DIVISION.md](TEAM_DIVISION.md)** for the complete file-by-file breakdown.

---

## 🔀 Git Workflow

The team followed a **feature-branch** workflow:

```
main
 ├── feature/m-auth-profile       ← M's branch (merged via PR)
 ├── feature/s-events-system      ← S's branch
 └── feature/a-news-components    ← A's branch
```

**Branching Rules:**
1. Each member created a feature branch from `main`
2. Work was scoped to assigned files; co-owned files were coordinated
3. Pull Requests were used for code review before merging
4. Commit messages follow the convention: `[M]`, `[S]`, `[A]` prefix

---

## 📦 Dependencies

| Package | Source | Version | Products Used |
|---------|--------|---------|---------------|
| **Firebase iOS SDK** | [github.com/firebase/firebase-ios-sdk](https://github.com/firebase/firebase-ios-sdk) | ≥ 10.0.0 | `FirebaseAuth`, `FirebaseFirestore`, `FirebaseFirestoreSwift` |

> **All other functionality** — `URLSession`, `SwiftUI`, `Combine`, `Foundation` — is part of the native iOS SDK. No additional third-party packages are required.

See **[DEPENDENCIES.md](DEPENDENCIES.md)** for detailed setup instructions.

---

## 📊 Project Metrics

| Metric | Value |
|--------|-------|
| Total Files | 42 |
| Total Lines of Code | ~4,800+ |
| Models | 5 |
| ViewModels | 7 |
| Views | 17 |
| Services | 3 |
| Utilities | 4 |
| Reusable Components | 4 |
| Firestore Collections | 2 (+1 subcollection) |

---

## 📄 License

This project is developed for **academic purposes** as part of a Mobile Computing course. All rights reserved by the contributors.

---

<p align="center">
  <strong>Built with ❤️ using SwiftUI + Firebase</strong><br>
  <em>CampusConnect — Connecting students to campus life</em>
</p>
