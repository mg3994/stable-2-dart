# Antinna Engine Documentation Index

Welcome to the Antinna Engine technical documentation. This engine is designed to transform Blogger posts into a fully functional e-commerce or service provider platform using strictly-typed Schema.org JSON-LD.

## Table of Contents

### User & Integration
1.  **[Integration Guide](integration.md)**
    *   How to add the engine to your Blogger XML template (IIFE and ESM methods).
2.  **[Availability Management](availability-management.md)**
    *   How to mark items as Out of Stock or Unavailable using Blogger.
3.  **[Google Pay Integration](google-pay.md)**
    *   Setup for Google Pay UPI India (Tez) with VPA and MCC details.
4.  **[Blogger Pagination](pagination.md)**
    *   Using the Blogger Feed API for dynamic post loading and infinite scroll.

### Technical Reference
5.  **[API Reference](api-reference.md)**
    *   Detailed documentation for all classes, methods, and global helpers.
6.  **[Architecture & Design](architecture.md)**
    *   Details on Clean Architecture, SOLID principles, and project structure.
7.  **[State Management](state-management.md)**
    *   Explains the `AppState` and reactive data flow.
8.  **[UI Components](ui-components.md)**
    *   Details on rendering components and `UIManager` utilities.
9.  **[Schema.org Compliance](schema-compliance.md)**
    *   How we strictly follow the Schema.org specification for Products and Services.

### For Developers
10. **[Development Guide](development-guide.md)**
    *   Build, test, and contribution workflows.

---

## Quick Start for Developers

To build the project locally:

```bash
# Install dependencies
npm install

# Build production bundles (dist/)
npm run build

# Run unit tests
npm run test
```
