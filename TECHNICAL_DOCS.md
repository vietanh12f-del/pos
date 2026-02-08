# Kiot - Smart POS System Documentation

## 1. System Overview hehe hihi

**Kiot** is a modern, voice-activated Point of Sale (POS) system designed for small cafes and retail stores in Vietnam. It leverages on-device speech recognition and custom Natural Language Processing (NLP) to convert voice commands into structured orders instantly.

### Key Features
- **Voice Order Entry**: Speak natural Vietnamese commands (e.g., "Cho 3 ly cà phê sữa và 1 bánh ngọt") to add items.
- **Smart Parsing**: Automatically detects quantities, item names, and prices, handling Vietnamese number formats and word-to-number conversion.
- **Instant Payment**: Generates VietQR codes for instant bank transfers.
- **Digital Receipts**: Renders and shares professional bill images via system share sheet.
- **Dashboard**: Real-time revenue and order tracking.

---

## 2. Architecture

The project follows the **MVVM (Model-View-ViewModel)** architectural pattern to separate UI logic from business rules.

### High-Level Diagram

```mermaid
graph TD
    User[User Voice/Touch] -->|Input| View[SwiftUI Views]
    View -->|Bind| VM[OrderViewModel]
    
    subgraph "Core Logic"
        VM -->|Listen| Speech[SpeechRecognizer]
        Speech -->|Transcript| VM
        VM -->|Parse Text| Parser[SmartParser]
        Parser -->|Structured Item| VM
    end
    
    subgraph "Data & Services"
        VM -->|Manage| Models[Models (Bill, OrderItem)]
        VM -->|Generate| QR[VietQR Service]
        VM -->|Render| Image[ImageRenderer]
    end
```

### Module Responsibilities

| Component | Responsibility |
|-----------|----------------|
| **ContentView.swift** | Main UI container, tab navigation, and view composition. |
| **OrderViewModel.swift** | Central state manager. Handles speech input, list management, and bill generation. |
| **SmartParser.swift** | The "Brain". Static utility that parses raw Vietnamese text into structured `OrderItem` objects. |
| **SpeechRecognizer.swift** | Wrapper around `SFSpeechRecognizer`. Handles microphone permissions and silence detection. |
| **Models.swift** | Data definitions (`OrderItem`, `Bill`, `Product`, `Category`). |

---

## 3. Key Components Detail

### 3.1 SmartParser (The NLP Engine)
Located in `SmartParser.swift`. This static class uses a multi-pass approach to understand orders.

- **Tokenization**: Uses `NLTokenizer` to split sentences.
- **Number Normalization**: 
  - Handles Vietnamese thousands separators (`2.000` -> `2000`).
  - Handles decimal commas (`2,5` -> `2.5`).
  - Maps number words (`ba`, `bốn`) to integers.
- **Logic**:
  - Identifies "quantity" (usually first number or number word).
  - Identifies "price" (usually large numbers at the end).
  - Extracts "name" (text between quantity and price).

### 3.2 OrderViewModel
Located in `OrderViewModel.swift`.

- **State**: Holds `items`, `totalAmount`, `revenue`, and `currentInput`.
- **Speech Integration**: Subscribes to `SpeechRecognizer.$transcript`. Debounces input to avoid flickering updates.
- **Price Memory**: Remembers prices for items (e.g., if you said "Cà phê 20k" once, next time "Cà phê" will auto-fill 20k).

### 3.3 Payment & Sharing
Located in `ContentView.swift` (PaymentView).

- **QR Code**: Generates a dynamic VietQR link (`https://img.vietqr.io...`) containing the bank info and exact amount.
- **Image Sharing**: 
  - Uses `ImageRenderer` to snapshot a clean version of the receipt (without UI buttons).
  - Pre-loads QR code images asynchronously before rendering to ensure they appear in the shared image.

---

## 4. Data Models

### OrderItem
```swift
struct OrderItem: Identifiable, Hashable {
    let id = UUID()
    var name: String
    var quantity: Int
    var price: Double
    var total: Double // Computed: quantity * price
}
```

### Bill
```swift
struct Bill: Identifiable {
    let id: UUID
    let createdAt: Date
    let items: [OrderItem]
    let total: Double
}
```

---

## 5. Developer Guide

### Prerequisites
- Xcode 15+
- iOS 17+ (Required for `Observation` framework if migrated, currently uses `ObservableObject`).
- Real device recommended for accurate Speech Recognition testing.

### Adding a New Feature
1.  **UI Changes**: Edit `ContentView.swift`. Keep views small and reusable.
2.  **Logic Changes**: Add methods to `OrderViewModel.swift`.
3.  **Parsing Improvements**: Add test cases to `SmartParser.swift` before modifying the regex/logic.

### Common Customizations
- **Bank Account**: Update the bank info in `OrderViewModel.swift` (`vietQRURL` method) and `ContentView.swift` (`BillReceiptView`).
- **Menu Items**: Update the `products` array in `OrderViewModel.swift` to change the quick-select grid.

---

## 6. Future Roadmap
- [ ] **Orders History**: Persist bills using SwiftData or CoreData.
- [ ] **Inventory Management**: Track stock levels based on orders.
- [ ] **Settings**: Allow users to configure bank info and shop name dynamically.
