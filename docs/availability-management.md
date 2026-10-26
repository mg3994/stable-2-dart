# Availability Management

This guide explains how to control the availability of your products and services in the Antinna Engine.

There are two primary ways an item becomes "unavailable" in the engine:

---

## 1. Schema-Level: "Out of Stock" (Standard)

This is the standard way to mark an item as temporarily unavailable while keeping the post active.

### How to trigger:
Update the `availability` property in your JSON-LD schema to `https://schema.org/OutOfStock`.

**Example:**
```json
"offers": {
  "@type": "Offer",
  "price": "499",
  "priceCurrency": "INR",
  "availability": "https://schema.org/OutOfStock"
}
```

### Result:
-   **Product Page**: The "Add to Shopping Bag" button becomes disabled and grayed out.
-   **Cart**: If the item was already in the bag, its price becomes blurred or lowered in opacity, signaling to the user it can no longer be ordered.

---

## 2. Engine-Level: "Currently Unavailable" (Draft/Deleted)

This occurs when the engine can no longer find the data source for an item that is already in a user's cart.

### How to trigger:
1.  **Revert to Draft**: Change your Blogger post from "Published" to "Draft".
2.  **Delete Post**: Completely remove the post from your blog.
3.  **Remove Schema**: Keep the post but remove the JSON-LD schema from the body.

### Result:
-   **Cart**: The item is marked with a bold red label: **"Currently Unavailable"**.
-   **Logic**: The quantity controls (+/-) are disabled, and the item is excluded from the **Total Price** calculation.
-   **Syncing**: The engine automatically detects this state whenever the user opens the cart.

---

## Making Items "Available" Again

To restore an item to the **"In Stock"** or **"Available"** state:

1.  **Standard**: Change the schema availability back to `https://schema.org/InStock`.
2.  **Restore**: Publish the draft post again or re-add the JSON-LD schema.

**Note**: Once an item is restored, the next time the user opens their shopping bag, the engine will automatically re-sync the data, remove the red warning label, and include the item back in the total price.
