# Project Structure

## Directory Organization

The project uses a **flat file structure** where all Swift source files are located directly in the `SmartKiot/` directory. While not organized into subdirectories, files follow logical naming conventions by feature area.

```
SmartKiot/
├── App Entry & Configuration
│   ├── kiotApp.swift              # App entry point
│   ├── AppDelegate.swift          # App lifecycle delegate
│   ├── AppIntents.swift           # Siri shortcuts integration
│   ├── SupabaseConfig.swift       # Backend configuration
│   └── Info.plist                 # App metadata and permissions
│
├── Core Architecture
│   ├── Models.swift               # Data models (OrderItem, Bill, Product, etc.)
│   ├── DatabaseManager.swift     # Database service abstraction
│   ├── AuthManager.swift         # Authentication singleton
│   ├── StoreManager.swift        # Multi-store management
│   └── StorageManager.swift      # File storage operations
│
├── Main Views & Navigation
│   ├── ContentView.swift         # Root view with tab navigation
│   ├── CustomTabBarView.swift   # Custom tab bar implementation
│   ├── WheelTabBarView.swift    # Wheel-style tab navigation
│   ├── EditTabBarView.swift     # Tab bar customization
│   └── TabBarConfig.swift       # Tab configuration
│
├── Feature: Authentication
│   ├── AuthenticationView.swift      # Login/signup UI
│   └── ProfileCreationView.swift    # User profile setup
│
├── Feature: Orders & Sales
│   ├── OrderViewModel.swift          # Core business logic (God Object)
│   ├── OrderHistoryView.swift       # Past orders list
│   ├── BillDetailView.swift         # Order detail view
│   ├── TransactionEditView.swift   # Edit completed orders
│   └── SmartParser.swift           # NLP text-to-order parser
│
├── Feature: Voice & AI
│   ├── SpeechRecognizer.swift       # Speech-to-text wrapper
│   ├── VoiceAIButton.swift          # Voice input button
│   ├── VoiceOverlayView.swift      # Voice recording UI
│   ├── VoiceOrderIntent.swift      # Siri integration
│   ├── OpenAIService.swift         # AI chat integration
│   └── SoundManager.swift          # Audio feedback
│
├── Feature: Inventory & Restock
│   ├── InventoryView.swift              # Stock management
│   ├── RestockEntryView.swift          # Add new stock
│   ├── RestockDetailView.swift         # Restock bill details
│   ├── RestockEditHistorySheet.swift  # Edit history tracking
│   ├── InvoiceScannerView.swift       # OCR invoice scanning
│   ├── ProductEditView.swift          # Edit product details
│   └── CostsAndImportsView.swift      # Import cost tracking
│
├── Feature: Barcode
│   ├── BarcodeScannerView.swift    # Scan product barcodes
│   ├── BarcodePrintView.swift      # Print barcode labels
│   ├── BarcodeLookupService.swift  # External barcode API
│   └── BarcodeUtils.swift          # Barcode utilities
│
├── Feature: Production & Materials
│   ├── ProductionManagementView.swift           # Production tracking
│   ├── ProductionReportView.swift              # Production reports
│   ├── ProductionTransactionItemEditView.swift # Edit production items
│   ├── MaterialEditView.swift                  # Edit raw materials
│   ├── AutoMaterialExportSheetView.swift       # Auto material deduction
│   ├── AutoMaterialExportLogDetailSheet.swift  # Export logs
│   └── ExternalProductAddView.swift            # Add external products
│
├── Feature: Analytics & Reports
│   ├── StatisticsView.swift           # Sales statistics
│   ├── FinancialReportService.swift  # Financial calculations
│   └── AddOperatingExpenseView.swift # Operating costs
│
├── Feature: Chat & Employees
│   ├── ChatView.swift              # Employee messaging
│   ├── ChatViewModel.swift         # Chat business logic
│   └── EmployeeManagementView.swift # Staff management
│
├── Feature: Multi-Store
│   ├── CreateStoreView.swift      # Create new store
│   └── StoreSelectionView.swift   # Switch between stores
│
├── Feature: Settings
│   ├── SettingsView.swift         # App settings
│   └── MoreView.swift             # Additional options
│
├── Shared Components
│   ├── Components.swift           # Reusable UI components
│   ├── ActionButton.swift         # Custom button styles
│   ├── CurrencyTextField.swift   # Currency input field
│   ├── ShareSheet.swift          # iOS share sheet wrapper
│   └── FormatUtils.swift         # Formatting utilities
│
├── Notifications
│   └── NotificationManager.swift  # Push notification handling
│
├── Database Migrations (SQL)
│   ├── schema.sql                 # Base schema
│   ├── enable_rls.sql            # Row Level Security
│   ├── enable_realtime_sync.sql  # Realtime subscriptions
│   ├── materials_schema.sql      # Materials tables
│   ├── production_schema.sql     # Production tables
│   └── alter_*.sql               # Schema migrations
│
└── Assets
    └── Assets.xcassets/          # Images, icons, colors
```

## Key Architectural Patterns

### God Object Pattern
- **`OrderViewModel.swift`** (~600+ lines) is the central state manager
- Handles: order entry, inventory, statistics, database sync
- **Refactoring opportunity**: Extract into smaller services

### View Composition
- Large feature views are self-contained in single files
- Reusable components extracted to `Components.swift`
- Navigation managed by `ContentView.swift`

### Service Layer
- Protocol-based abstractions (e.g., `DatabaseService`)
- Concrete implementations (e.g., `SupabaseDatabaseService` in `DatabaseManager.swift`)
- Singleton managers for shared state (`AuthManager`, `StoreManager`)

### Data Flow
1. **User Input** → View
2. **View** → ViewModel (via `@Published` bindings)
3. **ViewModel** → Service Layer
4. **Service** → Supabase Backend
5. **Backend** → Realtime updates → ViewModel → View

## File Naming Conventions

- **Views**: `*View.swift` (e.g., `OrderHistoryView.swift`)
- **ViewModels**: `*ViewModel.swift` (e.g., `OrderViewModel.swift`)
- **Managers**: `*Manager.swift` (e.g., `AuthManager.swift`)
- **Services**: `*Service.swift` (e.g., `FinancialReportService.swift`)
- **Utilities**: `*Utils.swift` or descriptive names (e.g., `SmartParser.swift`)
- **SQL Migrations**: Descriptive names (e.g., `alter_products_add_barcode.sql`)

## Important Notes

- **No subdirectories**: All Swift files are in the root `SmartKiot/` directory
- **SQL files**: Migration scripts are mixed with Swift files (consider moving to `migrations/` subdirectory)
- **Flat structure**: Relies on file naming and logical grouping rather than folder hierarchy
- **Assets**: Only `Assets.xcassets/` is in a subdirectory
