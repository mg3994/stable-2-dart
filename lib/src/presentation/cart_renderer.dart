import 'dart:js_interop';
import 'package:web/web.dart' as web;
import '../core/cart_manager.dart';
import '../core/schema_extractor.dart';
import 'ui_manager.dart';

class CartRenderer {
  final CartManager cartManager;

  CartRenderer(this.cartManager);

  void renderFab() {
    final container = UIManager.el("cart-fab-container");
    if (container == null) return;

    var fab = UIManager.el("cart-fab");
    if (fab == null) {
      fab = web.document.createElement("div");
      fab.id = "cart-fab";
      fab.className = "cart-fab";
      (fab as web.HTMLDivElement).onclick = ((web.MouseEvent e) {
        try {
          (web.window as dynamic).AntinnaEngine?.refreshCartData();
        } catch (_) {}
      }).toJS;

      final style = web.document.createElement('style');
      style.textContent = '''
        .cart-fab { position: fixed; bottom: 30px; right: 30px; z-index: 1000; transition: transform 0.3s; cursor: pointer; display: flex; align-items: center; justify-content: center; }
        .cart-fab.loading { pointer-events: none; opacity: 0.8; }
        .cart-spinner {
            display: none; width: 24px; height: 24px; border: 3px solid rgba(255,255,255,.3);
            border-radius: 50%; border-top-color: #fff; animation: cart-spin 1s ease-in-out infinite;
        }
        .cart-fab.loading .cart-spinner { display: block; }
        .cart-fab.loading .cart-icon { display: none; }
        .cart-fab.loading .cart-count { display: none; }
        @keyframes cart-spin { to { transform: rotate(360deg); } }
      ''';
      web.document.head?.appendChild(style);

      fab.innerHTML = '<span class="cart-icon">🛒</span><span class="cart-spinner"></span><span class="cart-count">0</span>';
      container.appendChild(fab);
    }
    updateUI();
  }

  void setLoading(bool loading) {
    final fab = UIManager.el("cart-fab");
    if (fab != null) {
      if (loading) {
        fab.classList.add("loading");
      } else {
        fab.classList.remove("loading");
      }
    }
  }

  void updateUI() {
    final count = cartManager.getTotalQuantity();
    final fab = UIManager.el("cart-fab");
    if (fab != null) {
      final countEl = fab.querySelector(".cart-count");
      if (countEl != null) countEl.textContent = count.toString();
      (fab as web.HTMLElement).style.transform = count > 0 ? "scale(1)" : "scale(0)";
    }
    final proceedBtn = UIManager.el("cart-proceed-btn") as web.HTMLButtonElement?;
    if (proceedBtn != null) {
      final isCartValid = cartManager.isCartValid();
      proceedBtn.disabled = count == 0 || !isCartValid;
      proceedBtn.style.opacity = proceedBtn.disabled ? '0.5' : '1';
    }
  }

  void showModal() {
    final backdrop = UIManager.el("cart-modal-backdrop");
    final drawer = UIManager.el("cart-drawer");
    final list = UIManager.el("cart-items-list");
    if (list == null) return;

    final footer = UIManager.query('.cart-footer');
    if (footer != null && UIManager.el('cart-proceed-btn') == null) {
      footer.innerHTML = '''
            <div style="display:flex; justify-content:space-between; font-weight:900; font-size:1.2rem; margin-bottom:20px;"><span>Total</span><span id="cart-total-price">--</span></div>
            <button class="v-btn active" id="cart-proceed-btn" onclick="AntinnaEngine.startCheckout()" style="width:100%; padding:18px; font-size:1.1rem; border-radius:12px;">Proceed</button>
        ''';
    }

    final order = cartManager.getOrder();
    final orderedItems = SchemaExtractor.getArray(order['orderedItem']);

    list.innerHTML = orderedItems.asMap().entries.map((entry) {
      final idx = entry.key;
      final item = entry.value;
      if (item is! Map) return '';

      final isUnavailable = item['isUnavailable'] == true;
      final orderedItem = item['orderedItem'];
      final offers = orderedItem is Map ? orderedItem['offers'] : null;
      final availability = SchemaExtractor.extractAvailability(offers);
      final isOutOfStock = availability == "https://schema.org/OutOfStock" || availability == "https://schema.org/SoldOut";

      final isOrderable = !isUnavailable && !isOutOfStock;
      final isQuantityValid = cartManager.isItemQuantityValid(item);
      final opacity = (isOrderable && isQuantityValid) ? '1' : '0.5';

      String statusText = '';
      if (isUnavailable) {
        statusText = '<div style="color:red; font-size:0.7rem; font-weight:800;">Currently Unavailable</div>';
      } else if (isOutOfStock) {
        statusText = '<div style="color:orange; font-size:0.7rem; font-weight:800;">Out of Stock</div>';
      } else if (!isQuantityValid) {
        final constraints = item['_constraints'];
        final minVal = constraints is Map ? constraints['minValue'] : null;
        statusText = '<div style="color:#ef4444; font-size:0.7rem; font-weight:800;">Minimum $minVal required</div>';
      }

      final qty = (item['orderQuantity'] as num? ?? 1).toInt();
      final priceMap = SchemaExtractor.extractPriceForQuantity(offers, qty);
      final bookingReq = SchemaExtractor.extractAdvanceBookingRequirement(offers);

      final addOnsHtml = SchemaExtractor.getArray(item['addOns']).asMap().entries.map((aEntry) {
        final aIdx = aEntry.key;
        final addon = aEntry.value;
        if (addon is! Map) return '';

        final addonOrderedItem = addon['orderedItem'];
        final addonOffers = addonOrderedItem is Map ? addonOrderedItem['offers'] : null;
        final addonQty = (addon['orderQuantity'] as num? ?? 1).toInt();
        final aPriceMap = SchemaExtractor.extractPriceForQuantity(addonOffers, addonQty);
        final aLimits = cartManager.getAddOnLimits(item, addon);

        final canDecrease = (aLimits['minValue'] == null) ? addonQty > 1 : addonQty > aLimits['minValue']!;
        final canIncrease = (aLimits['maxValue'] == null) || addonQty < aLimits['maxValue']!;

        final addonName = SchemaExtractor.getFirst(addonOrderedItem is Map ? addonOrderedItem['name'] : null)?.toString() ?? 'Addon';

        return '''
            <div style="display:flex; align-items:center; gap:10px; padding:10px 0; border-top:1px dashed rgba(0,0,0,0.05); margin-top:10px; font-size:0.8rem;">
               <div style="flex:1; opacity:0.8;">
                  <div style="font-weight:600;">+ $addonName</div>
                  <div style="color:var(--accent); font-weight:700;">${SchemaExtractor.getCurrencySymbol(aPriceMap['currency']!)}${aPriceMap['price']}</div>
               </div>
               <div style="display:flex; align-items:center; gap:8px;">
                  <button class="qty-btn" style="width:20px; height:20px; font-size:0.7rem;" ${!canDecrease ? 'disabled' : ''} onclick="cartUpdateAddOnQty($idx,$aIdx,-1)">-</button>
                  <span style="font-weight:600;">$addonQty</span>
                  <button class="qty-btn" style="width:20px; height:20px; font-size:0.7rem;" ${!canIncrease ? 'disabled' : ''} onclick="cartUpdateAddOnQty($idx,$aIdx,1)">+</button>
               </div>
               <button onclick="cartRemoveAddOn($idx,$aIdx)" style="background:none;border:none;color:#ff3b30;cursor:pointer;font-size:1rem; padding:5px;">×</button>
            </div>
          ''';
      }).join('');

      final name = SchemaExtractor.getFirst(orderedItem is Map ? orderedItem['name'] : null)?.toString() ?? 'Item';
      final constraints = item['_constraints'] as Map?;
      final maxVal = constraints?['maxValue'] as int?;

      return '''
        <div style="padding:15px; border-bottom:1px solid rgba(0,0,0,0.05); opacity:$opacity;">
          <div style="display:flex; gap:15px; align-items:center;">
             <img src="${_getItemImage(orderedItem)}" style="width:60px; height:60px; border-radius:10px; object-fit:cover;"/>
             <div style="flex:1;">
                <div style="font-weight:700;font-size:0.9rem;">$name</div>
                $statusText
                ${bookingReq != null ? '<div style="color:var(--accent); font-size:0.7rem; font-weight:700;">Booking: $bookingReq</div>' : ''}
                <div style="color:var(--accent); font-weight:800; font-size:0.85rem; margin-top:4px;">${SchemaExtractor.getCurrencySymbol(priceMap['currency']!)}${priceMap['price']}</div>
                <div style="display:flex; align-items:center; gap:12px; margin-top:10px;">
                   <button class="qty-btn" style="width:24px; height:24px; font-size:0.8rem;" ${!isOrderable ? 'disabled' : ''} onclick="cartUpdateQty($idx,-1)">-</button>
                   <span style="font-weight:800;">$qty</span>
                   <button class="qty-btn" style="width:24px; height:24px; font-size:0.8rem;" ${(!isOrderable || (maxVal != null && qty >= maxVal)) ? 'disabled' : ''} onclick="cartUpdateQty($idx,1)">+</button>
                </div>
             </div>
             <button onclick="cartRemoveItem($idx)" style="background:none;border:none;color:#ff3b30;cursor:pointer;font-size:1.2rem; padding:10px;">×</button>
          </div>
          <div style="margin-left: 75px;">
            $addOnsHtml
          </div>
        </div>
      ''';
    }).join("");

    if (list.innerHTML.isEmpty) {
      list.innerHTML = '<div style="text-align:center; padding:50px; opacity:0.5; font-weight:700;">Bag is empty</div>';
    }

    final totalEl = UIManager.el("cart-total-price");
    if (totalEl != null) {
      final currency = order['priceCurrency']?.toString() ?? 'INR';
      final total = order['totalPrice']?.toString() ?? '0';
      totalEl.textContent = "${SchemaExtractor.getCurrencySymbol(currency)}$total";
    }

    backdrop?.classList.add("active");
    drawer?.classList.add("active");
    updateUI();
  }

  void hideModal() {
    UIManager.el("cart-modal-backdrop")?.classList.remove("active");
    UIManager.el("cart-drawer")?.classList.remove("active");
  }

  String _getItemImage(dynamic item) {
    if (item is! Map) return '';
    final img = item['image'];
    if (img is List && img.isNotEmpty) {
      final first = img[0];
      if (first is Map) return first['url']?.toString() ?? '';
      return first.toString();
    }
    if (img is Map) return img['url']?.toString() ?? '';
    return img?.toString() ?? '';
  }
}
