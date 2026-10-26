# Schema.org Compliance

Antinna Engine is built on the philosophy of using the web's standard structured data as its primary database.

## Strict Compliance

We use the official [Schema.org JSON-LD](https://schema.org/docs/developers.html) vocabulary. Every interface in `src/types/schema.ts` is a direct representation of the Schema.org spec.

### Supported Main Types:
- **Product / ProductGroup**: For physical goods and variants.
- **Service**: For professional services.
- **LocalBusiness / Organization**: For seller details.
- **JobPosting**: (Future-proofed) For recruitment listings.
- **Order**: For managing the shopping bag and checkout.

### Standard Properties vs Custom Properties:
We strictly avoid custom properties like `isAddon` or `customID`. Instead, we use standard properties:
- `isAccessoryOrSparePartFor`: For related products.
- `isRelatedTo`: For linked services.
- `sku` / `gtin13`: For product identification.
- `hasVariant`: For product variations (color, size, etc.).

## Data Extraction Logic

The `SchemaExtractor` class parses post content. It is designed to find valid JSON-LD whether it is:
1.  Wrapped in `<script type="application/ld+json">` tags.
2.  Provided as a raw JSON string in the Blogger post HTML.

This allows for a "database-less" architecture where your Blogger posts *are* your product records.
