# Technology Stack

## Platform & Language

- **Platform**: iOS 17+
- **Language**: Swift 5.9+
- **UI Framework**: SwiftUI
- **Architecture**: MVVM (Model-View-ViewModel)

## Build System

- **IDE**: Xcode 15+
- **Build System**: Xcode Build System
- **Package Manager**: Swift Package Manager (SPM)

## Key Dependencies

### Backend & Services
- **Supabase Swift SDK** (v2.41.1): Backend-as-a-Service
  - Auth: Authentication and user management
  - PostgREST: Database operations
  - Realtime: Live data synchronization
  - Storage: File storage
  - Functions: Serverless functions

### Apple Frameworks
- **SFSpeechRecognizer**: Voice recognition for Vietnamese commands
- **Vision Framework**: OCR for invoice scanning
- **NaturalLanguage**: Text tokenization and NLP processing
- **AVFoundation**: Audio capture and playback

### Supporting Libraries
- **swift-crypto** (v4.2.0): Cryptographic operations
- **swift-http-types** (v1.5.1): HTTP type definitions
- **swift-concurrency-extras** (v1.3.2): Concurrency utilities
- **xctest-dynamic-overlay** (v1.8.1): Testing utilities

## Database

- **Type**: PostgreSQL (via Supabase)
- **Schema Management**: SQL migration files in `SmartKiot/` directory
- **Key Tables**: products, orders, order_items, restock_bills, restock_items, profiles, messages, stores, materials, production_transactions

## Common Commands

### Building
```bash
# Open project in Xcode
open SmartKiot.xcodeproj

# Build from command line
xcodebuild -project SmartKiot.xcodeproj -scheme SmartKiot -configuration Debug build
```

### Testing
- **Recommended**: Use a real iOS device for accurate speech recognition testing
- **Simulator**: Limited speech recognition capabilities
- No automated test suite currently exists (future roadmap item)

### Running
- Open `SmartKiot.xcodeproj` in Xcode
- Select target device (real device recommended)
- Press Cmd+R to build and run

## Configuration Files

- **Info.plist**: App permissions and configuration
- **SmartKiot.entitlements**: App capabilities (Sign in with Apple, Push Notifications)
- **SupabaseConfig.swift**: Backend connection settings (contains API keys)

## Code Style Conventions

- SwiftUI declarative syntax
- Combine framework for reactive programming
- `@Published` properties for observable state
- Protocol-based service abstractions (e.g., `DatabaseService`)
- Singleton pattern for managers (e.g., `AuthManager`, `StoreManager`)
