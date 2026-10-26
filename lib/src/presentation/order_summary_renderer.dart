import 'dart:js_interop';
import 'package:web/web.dart' as web;
import '../core/cart_manager.dart';
import '../core/schema_extractor.dart';
import '../infrastructure/google_pay_service.dart';
import 'ui_manager.dart';

class OrderSummaryRenderer {
  final CartManager cartManager;

  OrderSummaryRenderer(this.cartManager);

  void renderModal([dynamic verifiedLocation, dynamic orderDelivery]) {
    UIManager.injectModalStyles();

    var modal = UIManager.el('antinna-summary-modal');
    if (modal == null) {
      modal = web.document.createElement('div');
      modal.id = 'antinna-summary-modal';
      modal.className = 'antinna-geo-backdrop';
      web.document.body?.appendChild(modal);
    }

    final order = cartManager.getOrder();
    final serviceabilityErrors = cartManager.getServiceabilityErrors(verifiedLocation);
    final isServiceable = serviceabilityErrors.isEmpty;

    final orderedItems = SchemaExtractor.getArray(order['orderedItem']);

    final itemsHtml = orderedItems.map((item) {
      if (item is! Map) return '';
      final orderedItem = item['orderedItem'];
      final name = SchemaExtractor.getFirst(orderedItem is Map ? orderedItem['name'] : null)?.toString() ?? 'Item';
      final qty = (item['orderQuantity'] as num? ?? 1).toInt();
      final offers = orderedItem is Map ? orderedItem['offers'] : null;
      final priceMap = SchemaExtractor.extractPriceForQuantity(offers, qty);
      final price = double.tryParse(priceMap['price'] ?? '0') ?? 0.0;
      final currency = priceMap['currency'] ?? 'INR';
      final bookingReq = SchemaExtractor.extractAdvanceBookingRequirement(offers);

      final addOnsHtml = SchemaExtractor.getArray(item['addOns']).map((addon) {
        if (addon is! Map) return '';
        final addonItem = addon['orderedItem'];
        final aOffers = addonItem is Map ? addonItem['offers'] : null;
        final aQty = (addon['orderQuantity'] as num? ?? 1).toInt();
        final aPriceMap = SchemaExtractor.extractPriceForQuantity(aOffers, aQty);
        final aPrice = double.tryParse(aPriceMap['price'] ?? '0') ?? 0.0;
        final aCurrency = aPriceMap['currency'] ?? 'INR';
        final aName = SchemaExtractor.getFirst(addonItem is Map ? addonItem['name'] : null)?.toString() ?? 'Addon';

        return '''
                <div style="display:flex; justify-content:space-between; font-size:0.8rem; opacity:0.8; margin-top:4px;">
                    <span>+ $aName <b>x$aQty</b></span>
                    <span>${SchemaExtractor.getCurrencySymbol(aCurrency)}${(aPrice * aQty).toStringAsFixed(2)}</span>
                </div>
            ''';
      }).join('');

      return '''
            <div style="padding:10px 0; border-bottom:1px solid #eee; font-size:0.9rem;">
                <div style="display:flex; justify-content:space-between;">
                    <span style="flex:1;">$name <b>x$qty</b></span>
                    <span style="font-weight:700;">${SchemaExtractor.getCurrencySymbol(currency)}${(price * qty).toStringAsFixed(2)}</span>
                </div>
                $addOnsHtml
                ${bookingReq != null ? '<div style="font-size:0.75rem; color:var(--accent); margin-top:2px;">Booking: $bookingReq</div>' : ''}
            </div>
        ''';
    }).join('');

    String errorHtml = '';
    if (!isServiceable) {
      errorHtml = '''
            <div style="margin-bottom:20px; padding:15px; background:#fff5f5; border:1px solid #feb2b2; border-radius:12px; color:#c53030; font-size:0.85rem;">
                <div style="font-weight:800; margin-bottom:5px;">⚠️ Non-Serviceable Items</div>
                <p style="margin:0;">The following items are not available in your area:</p>
                <ul style="margin:5px 0 0 15px; padding:0;">
                    ${serviceabilityErrors.map((e) => '<li>$e</li>').join('')}
                </ul>
                <div style="margin-top:10px; font-weight:700;">Please remove these from your cart to continue.</div>
            </div>
        ''';
    }

    final maxLeadTime = cartManager.getMaxLeadTime();
    final travelDurationStr = (verifiedLocation is Map ? verifiedLocation['duration']?.toString() : null) ?? "0 mins";
    final travelMinutes = int.tryParse(RegExp(r'\d+').firstMatch(travelDurationStr)?.group(0) ?? '0') ?? 0;
    final totalMinutes = travelMinutes + maxLeadTime;

    String formattedEstTime = '$totalMinutes mins';
    if (totalMinutes >= 60) {
      final hours = totalMinutes ~/ 60;
      final mins = totalMinutes % 60;
      formattedEstTime = mins > 0 ? '${hours}h ${mins}m' : '${hours}h';
    }

    String destAddress = 'Verified Location';
    if (orderDelivery is Map && orderDelivery['deliveryAddress'] is Map) {
      final addr = orderDelivery['deliveryAddress'];
      destAddress = "${addr['extendedAddress']}, ${addr['streetAddress']}, ${addr['addressLocality']}";
    } else if (verifiedLocation is Map && verifiedLocation['address'] != null) {
      destAddress = verifiedLocation['address'].toString();
    }

    final distStr = (verifiedLocation is Map ? verifiedLocation['distance']?.toString() : null) ?? '--';

    modal.innerHTML = '''
      <div class="antinna-geo-content">
        <div class="antinna-geo-header">
          <h3>Order Summary</h3>
          <button class="antinna-geo-close" onclick="document.getElementById('antinna-summary-modal').classList.remove('active')">&times;</button>
        </div>

        $errorHtml

        <div style="margin-bottom:20px; padding:15px; background:var(--bg); border-radius:12px;">
            <div style="font-size:0.75rem; text-transform:uppercase; color:#777; margin-bottom:5px; font-weight:800;">Delivery Destination</div>
            <div style="font-weight:700; font-size:0.95rem;">
                $destAddress
            </div>
            <div style="font-size:0.8rem; color:var(--accent); margin-top:4px;">
                Distance: $distStr | Est. Time: $formattedEstTime
            </div>
        </div>

        <div style="max-height:200px; overflow-y:auto; margin-bottom:20px;">
            $itemsHtml
        </div>

        <div style="display:flex; justify-content:space-between; font-weight:900; font-size:1.2rem; margin:20px 0;">
            <span>Grand Total</span>
            <span>${SchemaExtractor.getCurrencySymbol(order['priceCurrency']?.toString() ?? 'INR')}${order['totalPrice'] ?? 0}</span>
        </div>

        <div id="google-pay-button-container" style="display:flex; justify-content:center; margin-top:20px;"></div>

        <p style="font-size:0.7rem; text-align:center; opacity:0.5; margin-top:15px;">
            By clicking Pay, you agree to our <a href="/p/terms-conditions.html" target="_blank" style="color:inherit; text-decoration:underline;">terms and conditions</a>.
        </p>
      </div>
    ''';

    modal.classList.add('active');
    _renderGooglePayButton(order, verifiedLocation, isServiceable);
  }

  void _renderGooglePayButton(Map<String, dynamic> order, dynamic verifiedLocation, bool isServiceable) {
    final container = UIManager.el('google-pay-button-container');
    if (container == null) return;
    container.innerHTML = '';

    if (!isServiceable) {
      container.innerHTML = '''
            <button class="v-btn" style="width:100%; opacity:0.5; cursor:not-allowed;" disabled>
                Check Coverage to Pay
            </button>
          ''';
      return;
    }

    final isDark = web.document.documentElement?.classList.contains('dark') ?? false;

    final btn = web.document.createElement('button') as web.HTMLButtonElement;
    btn.className = 'gpay-button ${isDark ? "white" : "black"}';
    btn.style.cssText = '''
          background-image: url('${isDark ? "https://www.gstatic.com/instantbuy/svg/light_gpay.svg" : "https://www.gstatic.com/instantbuy/svg/dark_gpay.svg"}');
          background-origin: content-box;
          background-position: center;
          background-repeat: no-repeat;
          background-size: contain;
          border: 0;
          border-radius: 4px;
          box-shadow: 0 1px 1px 0 rgba(60, 64, 67, 0.3), 0 1px 3px 1px rgba(60, 64, 67, 0.15);
          cursor: pointer;
          height: 48px;
          min-width: 160px;
          padding: 12px 24px;
          width: 100%;
          background-color: ${isDark ? '#fff' : '#000'};
      ''';

    btn.onclick = ((web.MouseEvent e) {
      GooglePayService().initPayment(order, verifiedLocation);
    }).toJS;

    container.appendChild(btn);
  }
}
