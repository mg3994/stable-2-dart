# API Reference

Detailed technical documentation for all classes and public methods in the Antinna Engine.

## Core Managers

### `CartManager`
Manages the shopping bag, order state, and persistence.

-   **`addItem(item: Product | Service, seller?: Organization): void`**
    -   Adds an item to the cart or increments its quantity if already present.
    -   Handles mapping of standard schema properties (SKU, GTIN, etc.).
-   **`removeItem(index: number): void`**
    -   Removes an item from the cart by its index.
-   **`updateQty(index: number, delta: number): void`**
    -   Updates the quantity of an item (+1 or -1). Removes item if quantity reaches zero.
-   **`getOrder(): Order`**
    -   Returns the current `Order` object (Schema.org compliant).
-   **`getTotalQuantity(): number`**
    -   Returns the sum of quantities for all items in the bag.
-   **`clear(): void`**
    -   Resets the cart and clears local storage.

### `LocationManager`
Handles geolocation and user-defined service area (PIN code).

-   **`getData(): LocationData`**
    -   Returns the current latitude, longitude, city, and PIN code.
-   **`setData(partial: Partial<LocationData>): void`**
    -   Updates specific location fields and persists to storage.
-   **`reverseGeocode(lat: number, lon: number): Promise<Partial<LocationData>>`**
    -   Fetches city and PIN code details using the OpenStreetMap Nominatim API.

---

## Infrastructure Services

### `BloggerDataService`
Interacts with the Blogger Feed API.

-   **`fetchFeedData(maxResults: number, startIndex: number): Promise<{entries: any[], totalResults: number}>`**
    -   Fetches a JSON feed of posts from the blog.
-   **`extractSchemaFromEntry(entry: any): any | null`**
    -   Extracts and parses JSON-LD data from a Blogger post entry object.

### `GooglePayService`
Handles the UPI (Tez) payment flow for India.

-   **`initPayment(order: Order): Promise<void>`**
    -   Constructs and launches the native `PaymentRequest` UI with the provided order details.

---

## Utilities

### `SchemaExtractor`
Static utility for parsing JSON-LD from HTML strings.

-   **`extractJsonLd<T>(input: string): T | null`**
    -   Parses raw JSON strings or content within `<script type="application/ld+json">` tags.
-   **`decodeEntities(text: string): string`**
    -   Converts HTML entities (e.g., `&quot;`) into standard characters for JSON parsing.

---

## Global Helpers (Window)

When using the IIFE bundle, the following are exposed globally:
-   `window.AntinnaEngine`: Instance of the main `App` class.
-   `window.CartManager`: Shortcut to `AntinnaEngine.CartManager`.
-   `window.LocationManager`: Shortcut to `AntinnaEngine.LocationManager`.
-   `window.loadMorePosts()`: Function to fetch and append the next page of posts.
-   `window.syncDots(el)`: Handles image dots synchronization for grid cards.
