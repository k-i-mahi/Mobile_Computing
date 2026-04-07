# CampusConnect — Swift Package Dependencies

## Add these via Xcode → File → Add Package Dependencies

### 1. Firebase iOS SDK
URL: https://github.com/firebase/firebase-ios-sdk
Version: Up To Next Major from 10.0.0

Products to add:
- FirebaseAuth
- FirebaseFirestore
- FirebaseFirestoreSwift

### Setup steps:
1. Create project at https://console.firebase.google.com
2. Add an iOS app (bundle ID must match your Xcode project)
3. Download GoogleService-Info.plist
4. Drag GoogleService-Info.plist into Xcode project root (tick "Copy if needed")
5. Enable Email/Password sign-in under Authentication → Sign-in method
6. Create Firestore database (start in test mode, then apply firestore.rules)
7. Paste firestore.rules into Firebase Console → Firestore → Rules

## No other external packages needed.
## All other functionality (URLSession, SwiftUI, Combine) is part of the iOS SDK.
