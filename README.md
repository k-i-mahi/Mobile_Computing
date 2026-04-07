# CampusConnect iOS App

A SwiftUI Event Management app implementing all 5 iOS Lab concepts.

---

## Team Ownership at a Glance

| Member | Owns |
|--------|------|
| **S** | App entry, Firebase init, Auth (login/signup/signout), Theme, Profile, Calendar, Settings |
| **M** | Event JSON model, events.json, EventList, EventDetail, EventFilter, Organizer screens, Cards/Badges |
| **A** | Firestore CRUD, My Events, Create/Edit/Delete Event, RSVP, NewsAPI, SeatCounter |

---

## Lab Coverage

| Lab | Concept | Where |
|-----|---------|-------|
| Lab 1 | Variables, optionals, nil-coalescing, switch, loops, functions, closures, tuples | Throughout all files — see comments |
| Lab 2 | SwiftUI Views, structs, stacks, navigation, business card | LoginView, EventCardView, OrganizerProfileView, DashboardView |
| Lab 3 | Codable, JSONDecoder, Bundle decode, URLSession, AsyncImage | Bundle+Decode, EventJSONViewModel, NewsAPIService, NewsViewModel |
| Lab 4 | Firebase Auth, Firestore CRUD, snapshot listeners, security rules | AuthViewModel, FirestoreEventManager, RSVPManager |
| Lab 5 | @State, @Binding, @ObservedObject, @StateObject, @EnvironmentObject | All ViewModels, SeatCounterView, ThemeManager, AuthRouterView |

---

## Project Setup (do this in order)

### Step 1 — Xcode Project
1. Open Xcode → New Project → iOS App
2. Product Name: `CampusConnect`
3. Interface: SwiftUI, Language: Swift
4. Save to your preferred location

### Step 2 — Create folder groups in Xcode
Right-click the project navigator and create groups matching:
```
App / Models / ViewModels / Views / Services / Utilities / Resources
```
Under Views, also create: Auth / Home / Events / Organizer / News / Profile / Settings / Calendar / Components

### Step 3 — Copy source files
Drag each `.swift` file into the matching Xcode group.
Make sure **"Copy items if needed"** and **"Add to target: CampusConnect"** are both checked.

### Step 4 — Add events.json
Drag `Resources/events.json` into the **Resources** group.
Confirm it appears in Xcode's Build Phases → Copy Bundle Resources.

### Step 5 — Firebase Setup
1. Go to https://console.firebase.google.com → New project
2. Add iOS app — set bundle ID to match your Xcode project (e.g. `com.yourname.campusconnect`)
3. Download `GoogleService-Info.plist` and drag it into the **root** of your Xcode project
4. In Xcode → File → Add Package Dependencies:
   - URL: `https://github.com/firebase/firebase-ios-sdk`
   - Version: Up To Next Major from `10.0.0`
   - Add products: **FirebaseAuth**, **FirebaseFirestore**, **FirebaseFirestoreSwift**
5. In Firebase Console → Authentication → Sign-in method → Enable **Email/Password**
6. In Firebase Console → Firestore Database → Create database (test mode to start)
7. Go to Firestore → Rules tab → paste contents of `firestore.rules` → Publish

### Step 6 — NewsAPI Key
1. Register free at https://newsapi.org
2. Copy your API key
3. Open `Utilities/Constants.swift`
4. Replace `"YOUR_NEWSAPI_KEY_HERE"` with your actual key

### Step 7 — Build & Run
- Select any iOS 17+ simulator
- Press ▶ (Cmd+R)
- Sign up with any email/password
- All features should work

---

## Architecture

```
CampusConnect
├── App/                     Entry point, Firebase init
├── Models/                  Pure data structs (Codable)
├── ViewModels/              ObservableObject classes, @Published state
├── Views/
│   ├── Auth/                Login + routing
│   ├── Home/                Tab dashboard
│   ├── Events/              List, Detail, Create, Edit, MyEvents, Filter
│   ├── Organizer/           Business card profile
│   ├── News/                NewsAPI list + detail
│   ├── Profile/             Editable user profile
│   ├── Settings/            Theme toggle
│   ├── Calendar/            Date-grouped events
│   └── Components/          Reusable cards, badges, counters
├── Services/                NewsAPIService, RSVPManager, ValidationService
├── Utilities/               Bundle+Decode, DateFormatterHelper, Constants
└── Resources/               events.json, GoogleService-Info.plist, Assets
```

---

## Git Branch Strategy

```
main          ← stable releases only
develop       ← integration branch
  ├── feature/S-auth-theme-profile
  ├── feature/M-events-json-organizer
  └── feature/A-firestore-news-rsvp
```

**Rules:**
- Never push directly to `main` or `develop`
- Open a PR into `develop` when your feature is stable
- Merge to `main` only after full integration test

---

## Firestore Data Structure

```
users/{uid}
  displayName, department, email, phone, bio

events/{eventId}
  title, description, venue, date, category,
  creatorUid, creatorEmail, createdAt

events/{eventId}/rsvps/{uid}
  uid, userEmail, eventId, timestamp
```

---

## Known Notes

- `NewsListView` shows a helpful empty state if the API key is missing or invalid
- `MyEventsView` uses a real-time Firestore snapshot listener — changes appear instantly
- `SeatCounterView` demonstrates `@Binding` passing from parent to child explicitly
- `ThemeManager` persists the selected theme in `UserDefaults` across launches
- All optional fields use `??` nil-coalescing throughout (Lab 1 requirement)
