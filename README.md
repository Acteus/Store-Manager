# 🏪 POS & Inventory Management System

A comprehensive **Point of Sale (POS) and Inventory Management System** built with **Flutter** for Android. This enterprise-grade application provides businesses with complete control over their inventory, sales transactions, and business analytics.

![Flutter](https://img.shields.io/badge/Flutter-3.0+-blue.svg)
![Dart](https://img.shields.io/badge/Dart-3.0+-blue.svg)
![Android](https://img.shields.io/badge/Platform-Android-green.svg)
![License](https://img.shields.io/badge/License-MIT-yellow.svg)

## Key Features

### **Core Functionality**
- **Point of Sale (POS)** - Complete transaction processing with cart management
- **Inventory Management** - Add, edit, remove, and track products
- **Barcode Integration** - Camera-based barcode scanning and generation
- **Manual Inventory Counting** - Physical stock counting with variance tracking
- **Sales History** - Comprehensive transaction records and reporting
- **Dashboard Analytics** - Real-time business insights and metrics

### 🚀 **Advanced Features**
- **Offline-First Architecture** - Works without internet connectivity
- **Real-time Sync** - Background data synchronization when online
- **Multi-device Support** - Responsive design for tablets and phones
- **Performance Optimization** - Virtual scrolling and intelligent caching
- **Security** - Input sanitization and data validation
- **Backup & Recovery** - Export/import data in multiple formats

### 🎨 **User Experience**
- **Material Design 3** - Modern, intuitive interface
- **Loading States** - Skeleton screens for smooth user experience
- **Error Handling** - Graceful error recovery with user-friendly messages
- **Dark/Light Theme** - Adaptive theming support
- **Accessibility** - Screen reader support and keyboard navigation

## **Technical Architecture**

### **State Management**
- **Riverpod** - Reactive state management with dependency injection
- **GetIt** - Service locator for dependency injection
- **Repository Pattern** - Clean separation of data and business logic

### **Database & Storage**
- **SQLite** - Local database with advanced indexing
- **Full-Text Search (FTS5)** - Fast product search capabilities
- **Shared Preferences** - User settings and cache management
- **File System** - Image storage and backup files

### **Performance**
- **Pagination** - Efficient data loading for large datasets
- **Caching Strategy** - Multi-level caching (memory + disk)
- **Virtual Scrolling** - Optimized list performance
- **Firebase Performance** - Real-time performance monitoring

### **Security & Reliability**
- **Input Sanitization** - Protection against injection attacks
- **Error Boundaries** - Crash prevention and recovery
- **Type Safety** - Full null-safety implementation
- **Data Validation** - Comprehensive form and input validation

## 📦 **Installation & Setup**

### **Prerequisites**
- Flutter SDK 3.0+
- Dart SDK 3.0+
- Android Studio or VS Code
- Android device/emulator (API level 21+)

### **Quick Start**

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/pos-inventory-system.git
   cd pos-inventory-system
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Run the application**
   ```bash
   flutter run
   ```

### **Build for Production**
```bash
# Build APK
flutter build apk --release

# Build App Bundle (recommended for Play Store)
flutter build appbundle --release
```

## **App Structure**

```
lib/
├── core/                    # Core infrastructure
│   ├── di/                 # Dependency injection
│   ├── error/              # Error handling
│   ├── security/           # Input sanitization
│   ├── services/           # Core services
│   ├── validation/         # Form validators
│   └── widgets/            # Reusable UI components
├── models/                 # Data models
├── providers/              # State management (Riverpod)
├── repositories/           # Data access layer
├── screens/                # UI screens
└── services/               # Business services
```

## 🔧 **Configuration**

### **Firebase Setup (Optional)**
For analytics and performance monitoring:

1. Create a Firebase project
2. Add your `google-services.json` to `android/app/`
3. Firebase will automatically initialize

### **Database Schema**
The app automatically creates and manages SQLite tables:
- `products` - Product inventory data
- `sales` - Transaction records
- `sale_items` - Individual sale line items
- `inventory_counts` - Physical count records
- `products_fts` - Full-text search index

## **Features Overview**

### **Point of Sale**
- Add products to cart via barcode scan or manual selection
- Calculate totals with tax support
- Multiple payment methods
- Receipt generation
- Transaction history

### **Inventory Management**
- Product CRUD operations
- Category management
- Stock level tracking
- Low stock alerts
- Bulk operations

### **Barcode Features**
- Camera-based scanning with `mobile_scanner`
- Generate barcodes for products
- Support for multiple barcode formats
- Quick product lookup

### **Analytics & Reporting**
- Sales performance metrics
- Inventory turnover analysis
- Top-selling products
- Revenue tracking
- Export capabilities

## **Dependencies**

### **Core Framework**
- `flutter` - UI framework
- `flutter_riverpod` - State management
- `get_it` - Dependency injection

### **Database & Storage**
- `sqflite` - SQLite database
- `shared_preferences` - Local storage
- `path_provider` - File system access

### **UI & UX**
- `google_fonts` - Typography
- `cached_network_image` - Image caching
- `reactive_forms` - Form validation

### **Hardware Integration**
- `mobile_scanner` - Barcode scanning
- `barcode_widget` - Barcode generation
- `image_picker` - Camera access

### **Utilities**
- `dartz` - Functional programming (Either type)
- `logger` - Logging
- `intl` - Internationalization

## **Contributing**

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## **License**

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## **Support**

- **Documentation**: Check the wiki for detailed guides
- **Issues**: Report bugs via GitHub Issues
- **Discussions**: Join community discussions
- **Email**: support@yourcompany.com

## **Roadmap**

### **Phase 1 - Current** ✅
- Core POS functionality
- Inventory management
- Barcode integration
- Offline support

### **Phase 2 - Planned** 🔄
- Cloud synchronization
- Multi-store support
- Advanced reporting
- Customer management

### **Phase 3 - Future** 📋
- Web dashboard
- API integrations
- Machine learning insights
- Enterprise features

---

**Built with using Flutter** • **Made for small businesses** • **Open source and customizable**
