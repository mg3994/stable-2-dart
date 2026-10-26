# Development Guide

This guide is for developers who want to modify or extend the Antinna Engine.

## Prerequisites

-   Node.js (Latest LTS version recommended)
-   npm

## Development Workflow

1.  **Installation**:
    ```bash
    npm install
    ```
2.  **Running Tests**:
    Always run tests before submitting changes to ensure no regressions in cart math or schema extraction.
    ```bash
    npm run test
    ```
3.  **Building**:
    Generates bundles for production.
    ```bash
    npm run build
    ```

## Extending the Engine

### Adding a new Schema Type
1.  Add the interface to `src/types/schema.ts`.
2.  Update `BloggerDataService.extractSchemaFromEntry` or the main `App` logic to handle the new type.
3.  Create a new renderer in `src/presentation` if needed.

### Customizing Google Pay
Modify `src/infrastructure/GooglePayService.ts`. You can add more `displayItems` or handle complex tax calculations here.

## Deployment

The project is configured with a GitHub Actions workflow (`.github/workflows/release.yml`).
-   Any push to any branch will trigger a build and test run.
-   Successful builds automatically create a new release on the GitHub **Releases** tab with the compiled `dist/` artifacts.

## Code Standards
-   **TypeScript**: Strict mode is enabled. Do not use `any` unless absolutely necessary (e.g., when dealing with raw Blogger JSON).
-   **Principles**: Follow SOLID and Clean Architecture. Keep the `core` layer free of DOM references.
