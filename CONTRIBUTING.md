# Contributing to POS & Inventory Management System

Thank you for your interest in contributing to our POS & Inventory Management System! This document provides guidelines and information for contributors.

## Getting Started

### Prerequisites
- Flutter SDK 3.0+
- Dart SDK 3.0+
- Android Studio or VS Code
- Git

### Development Setup

1. **Fork and Clone**
   ```bash
   git clone https://github.com/yourusername/pos-inventory-system.git
   cd pos-inventory-system
   ```

2. **Install Dependencies**
   ```bash
   flutter pub get
   ```

3. **Run Tests**
   ```bash
   flutter test
   ```

4. **Start Development Server**
   ```bash
   flutter run
   ```

## Project Structure

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

## Development Guidelines

### Code Style

1. **Follow Dart Style Guide**
   - Use `flutter analyze` to check for style issues
   - Run `dart format .` before committing
   - Keep lines under 80 characters when reasonable

2. **Naming Conventions**
   - Use `camelCase` for variables and functions
   - Use `PascalCase` for classes
   - Use `snake_case` for file names
   - Prefix private members with underscore `_`

3. **Architecture Patterns**
   - Use Repository pattern for data access
   - Implement proper separation of concerns
   - Use Riverpod for state management
   - Follow clean architecture principles

### Testing Requirements

1. **Unit Tests**
   - Write tests for all business logic
   - Test edge cases and error conditions
   - Aim for 80%+ code coverage

2. **Widget Tests**
   - Test UI components in isolation
   - Verify user interactions
   - Test different screen sizes

3. **Integration Tests**
   - Test complete user workflows
   - Verify database operations
   - Test barcode scanning functionality

### Commit Guidelines

1. **Commit Message Format**
   ```
   type(scope): brief description
   
   Detailed explanation of what changed and why.
   
   Fixes #issue_number
   ```

2. **Types**
   - `feat`: New feature
   - `fix`: Bug fix
   - `docs`: Documentation changes
   - `style`: Code style changes
   - `refactor`: Code refactoring
   - `test`: Adding or updating tests
   - `chore`: Maintenance tasks

3. **Examples**
   ```
   feat(pos): add support for multiple payment methods
   fix(inventory): resolve stock count calculation error
   docs(readme): update installation instructions
   test(models): add unit tests for Product model
   ```

## Bug Reports

When reporting bugs, please include:

1. **Environment Information**
   - Flutter version (`flutter --version`)
   - Device/emulator information
   - Operating system

2. **Steps to Reproduce**
   - Clear, numbered steps
   - Expected vs actual behavior
   - Screenshots/recordings if helpful

3. **Additional Context**
   - Error messages or logs
   - Related issues or PRs
   - Possible solutions you've tried

## Feature Requests

When requesting features:

1. **Use Case Description**
   - Who will use this feature?
   - What problem does it solve?
   - How does it benefit users?

2. **Detailed Requirements**
   - Functional requirements
   - Technical constraints
   - UI/UX considerations

3. **Implementation Suggestions**
   - Proposed approach
   - Alternative solutions
   - Breaking changes (if any)

## 🔄 Pull Request Process

1. **Before Starting**
   - Check existing issues and PRs
   - Discuss major changes in an issue first
   - Ensure you understand the requirements

2. **Development**
   - Create a feature branch from `main`
   - Write tests for your changes
   - Update documentation as needed
   - Follow coding standards

3. **Before Submitting**
   ```bash
   # Run tests
   flutter test
   
   # Check for analysis issues
   flutter analyze
   
   # Format code
   dart format .
   
   # Test on device
   flutter run
   ```

4. **PR Requirements**
   - Clear title and description
   - Link to related issues
   - Screenshots for UI changes
   - Test results summary

5. **Review Process**
   - Address reviewer feedback
   - Keep discussions constructive
   - Update PR description if scope changes

## Release Process

1. **Version Numbering**
   - Follow semantic versioning (MAJOR.MINOR.PATCH)
   - Update `pubspec.yaml` version
   - Tag releases in Git

2. **Changelog**
   - Document all user-facing changes
   - Group by feature/fix/breaking change
   - Include migration instructions for breaking changes

## Getting Help

- **Documentation**: Check the README and wiki
- **Issues**: Search existing issues first
- **Discussions**: Use GitHub Discussions for questions

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

## Recognition

Contributors will be acknowledged in:
- README.md contributors section
- Release notes for significant contributions
- Special recognition for ongoing contributors

Thank you for helping make this project better! 
