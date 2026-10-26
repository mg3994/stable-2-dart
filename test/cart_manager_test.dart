@TestOn('browser')
import 'package:test/test.dart';
import 'package:web/web.dart' as web;
import 'package:antinna_blogger_engine/src/core/cart_manager.dart';

void main() {
  group('CartManager', () {
    late CartManager cart;

    setUp(() {
      web.window.localStorage.clear();
      cart = CartManager();
    });

    test('should add item and calculate total', () {
      cart.addItem({
        "@type": "Product",
        'name': 'Item 1',
        'offers': {'price': 100, 'priceCurrency': 'INR'},
        'url': 'http://test.com/p1'
      });

      expect(cart.getTotalQuantity(), equals(1));
      expect(cart.getOrder()['totalPrice'], equals(100));
    });

    test('should increment quantity for same item with different prices (merging)', () {
      final item1 = {"@type": "Product", 'name': 'Item 1', 'offers': {'price': 100}, 'url': 'http://test.com/p1'};
      final item2 = {"@type": "Product", 'name': 'Item 1', 'offers': {'price': 120}, 'url': 'http://test.com/p1'};

      cart.addItem(item1);
      cart.addItem(item2);

      final items = cart.getOrder()['orderedItem'] as List;
      expect(items.length, equals(1));
      expect(cart.getTotalQuantity(), equals(2));
    });

    test('should update price in place and not duplicate during refresh', () {
      final item = {"@type": "Product", 'name': 'Item 1', 'offers': {'price': 100}, 'url': 'http://test.com/p1'};
      cart.addItem(item);

      final freshData = {"@type": "Product", 'name': 'Item 1', 'offers': {'price': 150}, 'url': 'http://test.com/p1'};
      cart.updateItemDetails(0, freshData);

      final items = cart.getOrder()['orderedItem'] as List;
      expect(items.length, equals(1));
      expect(cart.getOrder()['totalPrice'], equals(150));
    });

    test('should handle variants correctly and distinguish them', () {
      final base = {"@type": "Product", 'name': 'Phone', 'url': 'http://test.com/phone'};
      final v1 = {...base, 'color': 'Red', 'offers': {'price': 500}};
      final v2 = {...base, 'color': 'Blue', 'offers': {'price': 500}};

      cart.addItem(v1, null, {'color': 'Red'});
      cart.addItem(v2, null, {'color': 'Blue'});

      final items = cart.getOrder()['orderedItem'] as List;
      expect(items.length, equals(2));
    });
  });
}
