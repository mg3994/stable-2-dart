# State Management

The Antinna Engine uses a centralized but simple reactive state pattern to manage the UI across different interactions.

## `AppState` Interface

Defined in `src/types/app.ts`:

```typescript
export interface AppState {
  product: Product | ProductGroup | Service | null; // Current single product data
  selectedVariants: Record<string, string>;         // Selected attributes (Color, Size)
  currentSlide: number;                             // Active carousel index
  quantity: number;                                 // Quantity selector for the product page
  lastClickedAttribute: string | null;              // Used to resolve variant conflicts
  selectedPackage: any | null;                      // Current selection from OfferCatalog
}
```

## How State Flows

1.  **Extraction**: When a page loads, `SchemaExtractor` populates `state.product`.
2.  **Interaction**: When a user clicks a variant button (e.g., "Color: Red"), an event handler updates `state.selectedVariants`.
3.  **Reactive Rendering**: After every state change, the `ProductRenderer.render()` method is called. It:
    *   Finds the best matching variant from the schema based on `state.selectedVariants`.
    *   Re-renders the price, stock badge, and images to match the new selection.
4.  **Cart Sync**: When "Add to Cart" is clicked, the current state of the selected variant and quantity is passed to the `CartManager`.

## Persistence

While the `AppState` is volatile (resets on page refresh), the `CartManager` and `LocationManager` state are persisted automatically in `localStorage`. This ensures that items remain in the "Shopping Bag" even if the user closes the browser.
