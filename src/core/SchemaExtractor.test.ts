import { describe, it, expect } from 'vitest';
import { SchemaExtractor } from '../core/SchemaExtractor';

describe('SchemaExtractor', () => {
  it('should extract JSON-LD from script tag', () => {
    const html = '<script type="application/ld+json">{"@type": "Product", "name": "Test"}</script>';
    const result = SchemaExtractor.extractJsonLd<any>(html);
    expect(result?.name).toBe('Test');
  });

  it('should extract raw JSON-LD', () => {
    const raw = '{"@type": "Service", "name": "Clean"}';
    const result = SchemaExtractor.extractJsonLd<any>(raw);
    expect(result?.name).toBe('Clean');
  });

  it('should decode HTML entities', () => {
    const raw = '{"name": "Price &amp; Quality"}';
    const result = SchemaExtractor.extractJsonLd<any>(raw);
    expect(result?.name).toBe('Price & Quality');
  });

  describe('priceSpecification', () => {
    const offerWithSpecs = {
      "@type": "Offer",
      "priceSpecification": [
        {
          "@type": "UnitPriceSpecification",
          "price": "20.00",
          "priceCurrency": "INR",
          "eligibleQuantity": {
            "@type": "QuantitativeValue",
            "minValue": 1,
            "maxValue": 4,
            "unitCode": "C62"
          }
        },
        {
          "@type": "UnitPriceSpecification",
          "price": "15.00",
          "priceCurrency": "INR",
          "eligibleQuantity": {
            "@type": "QuantitativeValue",
            "minValue": 5,
            "unitCode": "C62"
          }
        }
      ]
    };

    it('should select correct price tier for small quantity', () => {
      const res = SchemaExtractor.extractPriceForQuantity(offerWithSpecs, 3);
      expect(res.price).toBe("20.00");
    });

    it('should select correct price tier for larger quantity', () => {
      const res = SchemaExtractor.extractPriceForQuantity(offerWithSpecs, 5);
      expect(res.price).toBe("15.00");
    });

    it('should fallback to standard price if no specs match', () => {
      const defaultOffer = {
        "@type": "Offer",
        "price": "25.00",
        "priceCurrency": "USD"
      };
      const res = SchemaExtractor.extractPriceForQuantity(defaultOffer, 10);
      expect(res.price).toBe("25.00");
      expect(res.currency).toBe("USD");
    });
  });
});
