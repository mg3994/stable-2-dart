import 'dart:js_interop';
import 'package:web/web.dart' as web;
import '../core/schema_extractor.dart';
import 'production_api_service.dart';

class GooglePayService {
  final String merchantId = "BCR2DN5TVPLKL4KZ";
  final String merchantName = "Antinna";

  Future<void> initPayment(Map<String, dynamic> order, [dynamic verifiedLocation]) async {
    final win = web.window as dynamic;
    if (win.PaymentRequest == null) {
      web.window.alert("Payment Request API not supported in this browser.");
      return;
    }

    try {
      await ProductionApiService.getInstance().createOrder({
        ...order,
        'verifiedLocation': verifiedLocation,
      });
    } catch (e) {
      web.console.error("Failed to record order in backend: $e".toJS);
    }

    final googlePayUPI = {
      'supportedMethods': 'https://tez.google.com/pay',
      'data': {
        'pa': 'manishsharma3994@okhdfcbank',
        'pn': merchantName,
        'tr': 'TR${DateTime.now().millisecondsSinceEpoch}',
        'url': web.window.location.href,
        'mc': '5251',
        'tn': 'Order from $merchantName',
      },
    };

    final googlePayGlobal = {
      'supportedMethods': 'https://google.com/pay',
      'data': {
        'environment': 'PRODUCTION',
        'apiVersion': 2,
        'apiVersionMinor': 0,
        'merchantInfo': {
          'merchantId': merchantId,
          'merchantName': merchantName,
        },
        'allowedPaymentMethods': [
          {
            'type': 'CARD',
            'parameters': {
              'allowedAuthMethods': ['PAN_ONLY', 'CRYPTOGRAM_3DS'],
              'allowedCardNetworks': ['MASTERCARD', 'VISA'],
            },
            'tokenizationSpecification': {
              'type': 'PAYMENT_GATEWAY',
              'parameters': {
                'gateway': 'example',
                'gatewayMerchantId': 'exampleGatewayMerchantId',
              },
            },
          },
        ],
      },
    };

    final supportedInstruments = [googlePayUPI, googlePayGlobal];

    final displayItems = <Map<String, dynamic>>[];
    final currency = order['priceCurrency']?.toString() ?? 'INR';

    final orderedItems = SchemaExtractor.getArray(order['orderedItem']);
    for (final item in orderedItems) {
      if (item is! Map) continue;
      final orderedItem = item['orderedItem'];
      final offers = orderedItem is Map ? orderedItem['offers'] : null;
      final priceData = SchemaExtractor.extractPrice(offers);
      final qty = (item['orderQuantity'] as num? ?? 1).toInt();
      final itemPrice = (double.tryParse(priceData['price'] ?? '0') ?? 0.0) * qty;

      final name = SchemaExtractor.getFirst(orderedItem is Map ? orderedItem['name'] : null)?.toString() ?? 'Item';
      displayItems.add({
        'label': '$name (x$qty)',
        'amount': {
          'currency': currency,
          'value': itemPrice.toStringAsFixed(2),
        },
      });

      final addOns = SchemaExtractor.getArray(item['addOns']);
      for (final addon in addOns) {
        if (addon is! Map) continue;
        final addonOrderedItem = addon['orderedItem'];
        final addonOffers = addonOrderedItem is Map ? addonOrderedItem['offers'] : null;
        final addonPriceData = SchemaExtractor.extractPrice(addonOffers);
        final addonQty = (addon['orderQuantity'] as num? ?? 1).toInt();
        final addonPrice = (double.tryParse(addonPriceData['price'] ?? '0') ?? 0.0) * addonQty;
        final addonName = SchemaExtractor.getFirst(addonOrderedItem is Map ? addonOrderedItem['name'] : null)?.toString() ?? 'Addon';

        displayItems.add({
          'label': '  + $addonName (x$addonQty)',
          'amount': {
            'currency': currency,
            'value': addonPrice.toStringAsFixed(2),
          },
        });
      }
    }

    if (verifiedLocation != null) {
      final addr = verifiedLocation is Map ? verifiedLocation['address']?.toString() ?? 'Verified Location' : 'Verified Location';
      displayItems.add({
        'label': 'Delivery: $addr',
        'amount': {
          'currency': currency,
          'value': '0.00',
        },
      });
    }

    final totalPrice = order['totalPrice']?.toString() ?? '0';

    final details = {
      'total': {
        'label': 'Total Amount',
        'amount': {
          'currency': currency,
          'value': totalPrice,
        },
      },
      'displayItems': displayItems,
    };

    try {
      final paymentRequest = win.PaymentRequest(supportedInstruments, details);
      await paymentRequest.canMakePayment();
      final response = await paymentRequest.show();
      web.console.log("Payment response: $response".toJS);
    } catch (e) {
      web.console.error("Payment Error: $e".toJS);
    }
  }
}
