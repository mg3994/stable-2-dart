# Architecture & Design

The Antinna Engine is built following modern software engineering principles to ensure maintainability, scalability, and performance.

## Clean Architecture

The project is organized into layers to separate concerns:

1.  **Domain Layer (`src/types`)**:
    *   Contains purely type definitions and interfaces.
    *   Strictly follows the Schema.org specification.
    *   Has zero dependencies on other layers.
2.  **Core Layer (`src/core`)**:
    *   Contains the essential business logic (Cart management, Location logic, Schema extraction).
    *   Framework-agnostic and zero-dependency.
3.  **Infrastructure Layer (`src/infrastructure`)**:
    *   Handles external systems (Google Pay API, Blogger Feed API).
    *   Implements the interfaces required by the core.
4.  **Presentation Layer (`src/presentation`)**:
    *   Handles DOM manipulation and UI rendering.
    *   Includes `UIManager` (utility), `ProductRenderer`, `CartRenderer`, and `LocationRenderer`.

## SOLID Principles

*   **Single Responsibility**: Each class (e.g., `CartManager`, `SchemaExtractor`) has one reason to change.
*   **Open/Closed**: The engine is designed to be extendable (e.g., adding a new `JobPostingRenderer`) without modifying core extraction logic.
*   **Liskov Substitution**: Standard Schema.org types (Product, Service) can be used interchangeably in the Cart where appropriate.
*   **Interface Segregation**: Clients only interact with the methods they need through exposed manager objects.
*   **Dependency Inversion**: High-level modules (the `App`) depend on abstractions and orchestrate specialized services.

## Project Structure

```text
src/
├── core/           # Business logic
├── infrastructure/ # External API integrations
├── presentation/   # UI & DOM rendering
├── types/          # Strict Schema.org & App interfaces
└── main.ts         # Entry point & global orchestration
```
