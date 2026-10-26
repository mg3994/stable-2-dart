@TestOn('browser')
import 'package:test/test.dart';
import 'package:antinna_blogger_engine/src/core/schema_extractor.dart';

void main() {
  group('SchemaExtractor', () {
    test('should extract JSON-LD from script tag', () {
      const html = '<script type="application/ld+json">{"@type": "Product", "name": "Test"}</script>';
      final result = SchemaExtractor.extractJsonLd(html);
      expect(result?['name'], equals('Test'));
    });

    test('should extract raw JSON-LD', () {
      const raw = '{"@type": "Service", "name": "Clean"}';
      final result = SchemaExtractor.extractJsonLd(raw);
      expect(result?['name'], equals('Clean'));
    });

    test('should decode HTML entities', () {
      const raw = '{"name": "Price &amp; Quality"}';
      final result = SchemaExtractor.extractJsonLd(raw);
      expect(result?['name'], equals('Price & Quality'));
    });

    group('priceSpecification', () {
      final offerWithSpecs = {
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

      test('should select correct price tier for small quantity', () {
        final res = SchemaExtractor.extractPriceForQuantity(offerWithSpecs, 3);
        expect(res['price'], equals("20.00"));
      });

      test('should select correct price tier for larger quantity', () {
        final res = SchemaExtractor.extractPriceForQuantity(offerWithSpecs, 5);
        expect(res['price'], equals("15.00"));
      });

      test('should fallback to standard price if no specs match', () {
        final defaultOffer = {
          "@type": "Offer",
          "price": "25.00",
          "priceCurrency": "USD"
        };
        final res = SchemaExtractor.extractPriceForQuantity(defaultOffer, 10);
        expect(res['price'], equals("25.00"));
        expect(res['currency'], equals("USD"));
      });
    });
  });
}
