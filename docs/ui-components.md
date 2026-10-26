# UI Components & Rendering

The presentation layer is responsible for turning raw Schema.org data into the interactive HTML elements you see on your blog.

## Renderers

### `ProductRenderer`
Responsible for the single product page layout.
*   **Carousel**: Dynamically builds the main image slider and thumbnails.
*   **Variant Selectors**: Generates buttons for every property in `variesBy`. Handles "Color" specially by using background images or colors.
*   **Stock Badge**: Maps Schema.org availability URLs (e.g., `InStock`) to readable, colored labels.
*   **Specifications**: Automatically generates a key-value list for properties like `model`, `material`, and `gtin`.

### `CartRenderer`
Manages the "Shopping Bag" drawer and floating action button (FAB).
*   **FAB**: Updates the badge count in real-time.
*   **Drawer**: Generates the list of cart items with quantity controls and "Remove" buttons.
*   **Checkout**: Triggers the Google Pay flow via `GooglePayService`.

### `LocationRenderer`
Handles the location detection modal and display.
*   **Modal**: Prompted if location is unset. Supports both browser Geolocation and manual PIN entry.
*   **Display**: Updates the navbar search field with the detected city and PIN.

## Global UI Utilities (`UIManager`)

A centralized utility for common DOM operations:
-   `el(id)`: Safe element selection.
-   `setContent(id, text)`: Updates text without risk of XSS.
-   `setHtml(id, html)`: Safe HTML injection for trusted content.
-   `showToast(msg, type)`: Displays floating feedback (Success/Error).
-   `toggleClass(id, class, force)`: Helper for animations and visibility.

## Dark Mode Support

All UI components are built to respect the `html.dark` class. Colors and shadows are defined using CSS variables in the template (e.g., `--bg`, `--card`, `--text`), which the renderers use for seamless theme integration.
