# Kiot POS - Architecture & Code Review Guide

## 1. System Overview

**Kiot** is a mobile Point of Sale (POS) application built with **SwiftUI** for iOS. It features voice-activated order entry, real-time inventory management, chat functionality for employees, and integration with **Supabase** for backend services (Auth, Database, Realtime).

### Tech Stack
- **Language**: Swift 5.9+
- **UI Framework**: SwiftUI
- **Architecture**: MVVM (Model-View-ViewModel)
- **Backend**: Supabase (PostgreSQL)
- **Local Intelligence**: Vision Framework (OCR), SFSpeechRecognizer (Voice), NaturalLanguage (NLP).

---

## 2. High-Level Architecture

The application follows a standard **MVVM** pattern, separating the UI (Views) from the business logic (ViewModels) and data definitions (Models).

### Layer Breakdown

1.  **Presentation Layer (Views)**
    -   **Container**: `ContentView.swift` acts as the root, managing the custom tab bar navigation.
    -   **Features**: Distinct views for Dashboard (`HomeDashboardView`), Orders (`SmartOrderEntryView`), Inventory (`RestockHistoryView`), and Chat (`ChatView`).
    -   **Components**: Reusable UI elements located in `Components.swift` (e.g., `StatCard`, `OrderRow`).

2.  **Business Logic Layer (ViewModels)**
    -   **`OrderViewModel`**: The core "God Object" of the app. Manages the product catalog, cart state, speech recognition processing, inventory logic, and statistics.
    -   **`ChatViewModel`**: Manages real-time messaging logic and employee lookup.
    -   **`AuthManager`**: Singleton responsible for authentication state and profile management.

3.  **Service Layer**
    -   **`DatabaseService`**: Protocol-based abstraction for data operations.
    -   **`SupabaseDatabaseService`**: Concrete implementation interacting with the Supabase SDK.
    -   **`SpeechRecognizer`**: Wrapper for `SFSpeechRecognizer` handling audio buffers and permissions.
    -   **`SmartParser`**: Static utility using Regex and NLP heuristics to parse unstructured text (voice/OCR) into structured data (`OrderItem`).

4.  **Data Layer (Models)**
    -   **Entities**: Defined in `Models.swift` (`Product`, `Bill`, `OrderItem`, `UserProfile`).
    -   **DTOs**: Data Transfer Objects defined in `DatabaseManager.swift` to map between Swift structs and SQL tables.

---

## 3. Key Data Flows

### 3.1 Voice-to-Order Flow
1.  **Input**: User speaks into the microphone (`SmartOrderEntryView`).
2.  **Capture**: `SpeechRecognizer` captures audio and streams text transcript to `OrderViewModel`.
3.  **Processing**: `OrderViewModel` debounces the input and passes text to `SmartParser`.
4.  **Parsing**: `SmartParser` identifies Quantity, Product Name, and Price using NLP/Regex.
5.  **Mapping**: `OrderViewModel` attempts to match the parsed name with the existing `products` catalog (Fuzzy Matching).
6.  **State Update**: Valid items are appended to the `items` array, updating the UI instantly.

### 3.2 Restock & Inventory Flow
1.  **Input**: User scans an invoice image (`InvoiceScannerView`).
2.  **OCR**: Vision framework extracts text from the image.
3.  **Parsing**: Text is parsed into `RestockItem` objects.
4.  **Commit**: Upon confirmation, `OrderViewModel` calculates the new **Moving Average Cost (AVCO)** for products and updates the `products` table and `inventory` dictionary.

---

## 4. Code Review Guidelines

When reviewing code in this repository, focus on the following specific areas:

### 4.1 Architectural Concerns
-   **Monolithic ViewModel**: `OrderViewModel.swift` is currently very large (~600+ lines). It handles Order Entry, Inventory, Stats, and Database Sync.
    -   *Recommendation*: Look for opportunities to extract logic into smaller services (e.g., `InventoryManager`, `StatisticsService`).
-   **View Composition**: `ContentView.swift` contains multiple large structs (`HomeDashboardView`, `SmartOrderEntryView`).
    -   *Recommendation*: Ensure new features are created in separate files to maintain readability.

### 4.2 Security & Configuration
-   **API Keys**: `SupabaseConfig.swift` currently contains hardcoded API keys.
    -   *Critical*: Ensure these are rotated or moved to a secure build configuration/xcconfig before public release, although Supabase Anon keys are generally safe for client-side if RLS is configured.
-   **Row Level Security (RLS)**: Check `enable_rls.sql`. Currently, policies allow `ALL` access for `true` (public).
    -   *Critical*: For production, RLS policies must restrict access based on `auth.uid()`.

### 4.3 Performance
-   **Main Thread Usage**: `OrderViewModel` performs heavy calculations (`recalculateStats`) on the main thread.
    -   *Check*: Ensure heavy array reductions or database mapping happen in `Task.detached` or background threads where possible.
-   **Image Rendering**: `PaymentView` uses `ImageRenderer` to generate receipts.
    -   *Check*: Ensure this doesn't block the UI during the "Share" action.

### 4.4 Robustness (The "Smart" Logic)
-   **SmartParser Fragility**: The parser relies on specific keywords (e.g., "k", "đ") and regex patterns.
    -   *Review*: Any changes to `SmartParser.swift` must be tested against edge cases (e.g., "2000" vs "2.000").
-   **Offline Handling**: `DatabaseManager.swift` has a mock implementation, but the app primarily assumes a connection.
    -   *Check*: Verify how the app behaves if `isDatabaseConnected` is false.

---

## 5. Database Schema (Inferred)

Based on `Models.swift` and `DatabaseManager.swift`:

| Table | Description | Key Columns |
| :--- | :--- | :--- |
| `products` | Catalog items | `id`, `name`, `price`, `cost_price`, `stock_quantity` |
| `orders` | Sales transactions | `id`, `total_amount`, `created_at` |
| `order_items` | Items within a sale | `id`, `order_id`, `product_name`, `quantity`, `price` |
| `restock_bills` | Import transactions | `id`, `total_cost`, `created_at` |
| `restock_items` | Items within an import | `id`, `bill_id`, `product_name`, `quantity`, `unit_price` |
| `profiles` | User/Employee data | `id` (FK to auth), `full_name`, `role` |
| `messages` | Chat history | `id`, `sender_id`, `receiver_id`, `content` |

---

## 6. Directory Structure

```text
kiot/
├── App/
│   ├── kiotApp.swift           # Entry Point
│   ├── ContentView.swift       # Main Navigation & Dashboard
│   └── SupabaseConfig.swift    # Config
├── Features/
│   ├── Auth/                   # AuthenticationView, ProfileCreation
│   ├── Orders/                 # SmartOrderEntry, OrderHistory
│   ├── Inventory/              # RestockHistory, GoodsView, InvoiceScanner
│   ├── Chat/                   # ChatView, ChatDetail
│   └── Settings/               # SettingsView
├── Core/
│   ├── ViewModels/             # OrderViewModel, ChatViewModel
│   ├── Models/                 # Models.swift
│   ├── Services/               # DatabaseManager, AuthManager
│   └── Utils/                  # SmartParser, SpeechRecognizer
└── UI/
    ├── Components/             # Shared UI Components
    └── Navigation/             # WheelTabBarView, TabBarConfig
```

## 7. Future Refactoring Goals

1.  **Refactor `OrderViewModel`**: Split into `OrderService` (transactional) and `InventoryService` (management).
2.  **Localization**: Move hardcoded strings (Vietnamese) to `Localizable.strings`.
3.  **Testing**: Add Unit Tests for `SmartParser` to ensure regex logic doesn't regress.
```

<!--
[PROMPT_SUGGESTION]Refactor OrderViewModel by extracting the inventory management logic into a separate InventoryService class.[/PROMPT_SUGGESTION]
[PROMPT_SUGGESTION]Write unit tests for the SmartParser class to verify it correctly parses Vietnamese voice commands.[/PROMPT_SUGGESTION]
