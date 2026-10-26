import 'dart:convert';
import 'dart:js_interop';
import 'package:web/web.dart' as web;
import '../types/app.dart';
import '../core/schema_extractor.dart';
import 'ui_manager.dart';

class ProductRenderer {
  void render(dynamic p, AppState state, Function(String attr, String val) onVariantChange) {
    UIManager.injectModalStyles();
    final pMap = p is Map ? p : {};
    final pType = SchemaExtractor.getFirst(pMap['@type'])?.toString() ?? '';
    final isBusiness = pType == "LocalBusiness" || pType == "Store" || pType == "Organization";
    final isPrimaryService = pType == "Service";

    if (isBusiness) {
      _renderBusinessView(pMap);
    } else {
      final variant = SchemaExtractor.findMatchingVariant(pMap, state.selectedVariants, state.lastClickedAttribute);

      if (variant != null && pMap['variesBy'] != null) {
        final variesBy = SchemaExtractor.getArray(pMap['variesBy']);
        for (final u in variesBy) {
          final uStr = u is String ? u : SchemaExtractor.getFirst(u is Map ? (u['url'] ?? u['name']) : null)?.toString() ?? '';
          final a = uStr.split(RegExp(r'[\/#]')).last;
          if (variant is Map) {
            final variantVal = SchemaExtractor.getFirst(variant[a]);
            if (variantVal != null) state.selectedVariants[a] = variantVal.toString();
          }
        }
      }

      final variantMap = variant is Map ? variant : {};

      UIManager.setContent("p-name", SchemaExtractor.getFirst(variantMap['name'])?.toString() ?? SchemaExtractor.getFirst(pMap['name'])?.toString() ?? '');
      UIManager.setContent("p-desc", SchemaExtractor.getFirst(variantMap['description'])?.toString() ?? SchemaExtractor.getFirst(pMap['description'])?.toString() ?? '');
      UIManager.setContent("p-sku", variantMap['sku'] != null ? "SKU: ${SchemaExtractor.getFirst(variantMap['sku'])}" : "");

      final variantBrand = SchemaExtractor.getFirst(variantMap['brand'] ?? pMap['brand']);
      final brand = variantBrand is String ? variantBrand : SchemaExtractor.getFirst(variantBrand is Map ? variantBrand['name'] : null)?.toString();
      UIManager.setContent("p-brand", brand ?? "");

      final offer = SchemaExtractor.getFirst(variantMap['offers'] ?? pMap['offers']);
      final priceEl = UIManager.el("p-price");
      if (priceEl != null && offer != null) {
        final priceData = SchemaExtractor.extractPriceForQuantity(offer, state.quantity);
        final symbol = SchemaExtractor.getCurrencySymbol(priceData['currency']!);
        priceEl.textContent = "$symbol${priceData['price']}";
        final availability = SchemaExtractor.extractAvailability(offer);
        priceEl.classList.toggle("blurry", availability == "https://schema.org/OutOfStock");
      }

      _renderStockBadge(offer);
      _renderConditionBadge(variant ?? pMap);
      _renderAreaServed(pMap);

      final imgsRaw = (variantMap['image'] ?? pMap['image']);
      final List imgs = imgsRaw is List ? imgsRaw : [imgsRaw];
      _renderCarousel(imgs.where((i) => i != null).toList());

      final modelUrl = SchemaExtractor.extract3DModel(variant) ?? SchemaExtractor.extract3DModel(pMap);
      _render3DButton(modelUrl);

      _renderQuantityConstraints(offer);
      _renderVariants(pMap, state, onVariantChange);
      _renderSpecs(variantMap, pMap);

      UIManager.toggleClass(".qty-controls", "hidden", isPrimaryService);
      UIManager.toggleClass("#add-to-cart-btn", "hidden", false);

      final offerMap = offer is Map ? offer : {};
      final seller = offerMap['seller'] ?? (pMap['offers'] is Map ? pMap['offers']['seller'] : null) ?? pMap['seller'] ?? pMap['provider'];

      renderSeller(seller);
      _renderOtherServices(seller, variantMap.isNotEmpty ? variantMap : pMap, state);
    }
  }

  void _renderBusinessView(Map b) {
    UIManager.setContent("p-name", SchemaExtractor.getFirst(b['name'])?.toString() ?? '');
    UIManager.setContent("p-desc", SchemaExtractor.getFirst(b['description'])?.toString() ?? "");
    UIManager.setContent("p-brand", SchemaExtractor.getFirst(b['@type'])?.toString() ?? '');

    final priceEl = UIManager.el("p-price");
    if (priceEl != null) priceEl.textContent = "Service Provider";

    UIManager.toggleClass("#p-sku", "hidden", true);
    UIManager.toggleClass("#stock-badge-container", "hidden", true);
    UIManager.toggleClass("#p-variants", "hidden", true);
    UIManager.toggleClass(".qty-controls", "hidden", true);
    UIManager.toggleClass("#add-to-cart-btn", "hidden", true);

    _renderCarousel(b['image'] is List ? b['image'] : [b['image']]);
    renderSeller(b);
    _renderOtherServices(b, b, AppState());
  }

  void _renderConditionBadge(dynamic data) {
    final container = UIManager.el('stock-badge-container');
    if (container == null) return;

    final condition = SchemaExtractor.extractCondition(data);
    final existing = UIManager.el('p-condition-badge');
    if (existing != null) existing.remove();

    if (condition != null) {
      final badge = web.document.createElement('span');
      badge.id = 'p-condition-badge';
      badge.className = 'condition-badge cond-${condition.toLowerCase()}';
      badge.textContent = condition;
      container.appendChild(badge);
    }
  }

  void _renderStockBadge(dynamic offer) {
    final st = UIManager.el("stock-badge-container");
    if (st != null && offer != null) {
      UIManager.toggleClass("#stock-badge-container", "hidden", false);
      final av = SchemaExtractor.extractAvailability(offer);
      String label = 'Out of Stock', css = 'out-stock';
      bool available = false;

      if (av == 'https://schema.org/InStock' || av == 'https://schema.org/OnlineOnly') {
        label = 'In Stock'; css = 'in-stock'; available = true;
      } else if (av == 'https://schema.org/InStoreOnly') {
        label = 'In-Store Only'; css = 'instore-only'; available = false;
      } else if (av == 'https://schema.org/PreOrder') {
        label = 'Pre-Order'; css = 'pre-order'; available = true;
      }

      st.innerHTML = '<span class="stock-badge $css">$label</span>';
      final addBtn = UIManager.el("add-to-cart-btn") as web.HTMLButtonElement?;
      if (addBtn != null) {
        UIManager.toggleClass("#add-to-cart-btn", "hidden", false);
        addBtn.disabled = !available;
      }
    }
  }

  void _renderAreaServed(Map s) {
    final pDesc = UIManager.el('p-desc');
    final areaServed = SchemaExtractor.getFirst(s['areaServed']);
    if (areaServed != null && pDesc != null) {
      final area = areaServed is String
          ? areaServed
          : (SchemaExtractor.getFirst(areaServed is Map ? areaServed['name'] : null) ?? SchemaExtractor.getFirst(areaServed is Map ? areaServed['@type'] : null));
      final existing = UIManager.el('svc-area-badge');
      if (existing != null) existing.remove();

      final ab = web.document.createElement('div') as web.HTMLDivElement;
      ab.id = 'svc-area-badge';
      ab.className = 'geo-badge';
      ab.style.background = '#e8f5e9';
      ab.style.color = '#2e7d32';
      ab.style.marginBottom = '15px';
      ab.innerHTML = '&#127760; <b>Area Served:</b> $area';
      pDesc.before(ab);
    }
  }

  void _renderQuantityConstraints(dynamic offer) {
    final limits = SchemaExtractor.extractEligibleQuantity(offer);
    final minValue = limits['minValue'];
    final maxValue = limits['maxValue'];
    final inventoryLevel = SchemaExtractor.extractInventoryLevel(offer);
    final effectiveMax = (maxValue != null && inventoryLevel != null)
        ? (maxValue < inventoryLevel ? maxValue : inventoryLevel)
        : (maxValue ?? inventoryLevel);

    final container = UIManager.query('.qty-controls');
    if (container == null) return;

    final existingHint = UIManager.el('qty-constraints-hint');
    if (existingHint != null) existingHint.remove();

    if (minValue != null || effectiveMax != null) {
      final hint = web.document.createElement('div');
      hint.id = 'qty-constraints-hint';
      (hint as web.HTMLElement).style.cssText = 'font-size: 0.75rem; color: #777; margin-top: 8px; font-weight: 600;';

      String text = '';
      if (minValue != null && effectiveMax != null) {
        text = 'Min: $minValue, Max: $effectiveMax';
        if (inventoryLevel != null && inventoryLevel < (maxValue ?? 999999)) {
          text += ' (Limited Stock)';
        }
      } else if (minValue != null) {
        text = 'Minimum order: $minValue';
      } else if (effectiveMax != null) {
        text = 'Maximum order: $effectiveMax';
        if (inventoryLevel != null && inventoryLevel < (maxValue ?? 999999)) {
          text += ' (Limited Stock)';
        }
      }

      hint.textContent = text;
      container.after(hint);
    }

    (web.window as dynamic).currentQuantityLimits = {'minValue': minValue, 'maxValue': effectiveMax};
    updateQtyButtons();
  }

  void updateQtyButtons() {
    final limits = (web.window as dynamic).currentQuantityLimits;
    final qtyPlus = UIManager.el("qty-plus") as web.HTMLButtonElement?;
    final currentQty = int.tryParse(UIManager.el("qty-val")?.textContent ?? "1") ?? 1;

    if (qtyPlus != null && limits != null && limits['maxValue'] != null) {
      qtyPlus.disabled = currentQty >= (limits['maxValue'] as int);
      qtyPlus.style.opacity = qtyPlus.disabled ? '0.5' : '1';
    }
  }

  void _renderCarousel(List imgs) {
    final inner = UIManager.el("carousel-inner");
    final thumbRow = UIManager.el("thumbnail-row");
    if (inner == null) return;
    inner.innerHTML = "";
    if (thumbRow != null) thumbRow.innerHTML = "";

    for (int i = 0; i < imgs.length; i++) {
      final s = imgs[i];
      final url = s is Map ? (s['url']?.toString() ?? '') : s.toString();
      final d = web.document.createElement("div");
      d.className = "carousel-item";
      d.innerHTML = '<img src="$url"/>';
      inner.appendChild(d);

      if (thumbRow != null && imgs.length > 1) {
        final t = web.document.createElement("img") as web.HTMLImageElement;
        t.className = "thumb${i == 0 ? " active" : ""}";
        t.src = url;
        t.onclick = ((web.MouseEvent e) {
          try {
            (web.window as dynamic).AntinnaEngine?.goToSlide(i);
          } catch (_) {}
        }).toJS;
        thumbRow.appendChild(t);
      }
    }
    (inner as web.HTMLElement).style.transform = "translateX(0)";
  }

  void _render3DButton(String? url) {
    final container = UIManager.query('.carousel-container');
    if (container == null) return;

    final existing = UIManager.el('view-3d-btn');
    if (existing != null) existing.remove();

    if (url == null || url.isEmpty) return;

    final btn = web.document.createElement('button') as web.HTMLButtonElement;
    btn.id = 'view-3d-btn';
    btn.className = 'v-btn';
    btn.style.cssText = '''
        margin-top: 15px; width: 100%;
        background: rgba(0,0,0,0.8); color: #fff; border: none;
        padding: 12px 20px; border-radius: 12px; font-weight: 700;
        display: flex; align-items: center; justify-content: center; gap: 10px; font-size: 0.95rem;
      ''';
    btn.innerHTML = '<span>📦</span> View in 3D Preview';
    btn.onclick = ((web.MouseEvent e) => UIManager.show3DViewer(url)).toJS;
    container.appendChild(btn);
  }

  void _renderVariants(Map p, AppState state, Function(String attr, String val) onVariantChange) {
    final vc = UIManager.el("p-variants");
    if (vc != null && vc.children.length == 0) {
      if (p['variesBy'] != null) {
        UIManager.toggleClass("#p-variants", "hidden", false);
        final variesBy = SchemaExtractor.getArray(p['variesBy']);
        for (final u in variesBy) {
          final uStr = u is String ? u : SchemaExtractor.getFirst(u is Map ? (u['url'] ?? u['name']) : null)?.toString() ?? '';
          final a = uStr.split(RegExp(r'[\/#]')).last;
          final variants = SchemaExtractor.getArray(p['hasVariant']);
          final vals = variants.map((x) => SchemaExtractor.getFirst(x is Map ? x[a] : null)).where((v) => v != null).toSet().toList();
          if (vals.isEmpty) continue;

          final g = web.document.createElement("div");
          g.className = "v-group";
          g.innerHTML = '<span class="v-label">Select $a</span>';
          final os = web.document.createElement("div");
          os.className = "v-options";

          for (final vl in vals) {
            final btn = web.document.createElement("button") as web.HTMLButtonElement;
            btn.className = "v-btn";
            btn.setAttribute("data-attr", a);
            btn.setAttribute("data-val", vl.toString());

            if (a.toLowerCase() == "color") {
              btn.classList.add("v-color");
              final match = variants.firstWhere((x) => x is Map && SchemaExtractor.getFirst(x[a])?.toString() == vl.toString(), orElse: () => null);
              final vi = match is Map ? SchemaExtractor.getFirst(match['image']) : null;
              if (vi != null) {
                final url = vi is Map ? vi['url'] : vi;
                btn.style.backgroundImage = "url('$url')";
              } else {
                btn.style.backgroundColor = vl.toString();
              }
              btn.title = vl.toString();
            } else {
              btn.textContent = vl.toString();
            }

            btn.onclick = ((web.MouseEvent e) => onVariantChange(a, vl.toString())).toJS;
            os.appendChild(btn);
          }

          g.appendChild(os);
          vc.appendChild(g);
          if (state.selectedVariants[a] == null) state.selectedVariants[a] = vals[0].toString();
        }
      } else if (p['hasOfferCatalog'] != null) {
        UIManager.toggleClass("#p-variants", "hidden", false);
        final g = web.document.createElement("div");
        g.className = "v-group";
        g.innerHTML = '<span class="v-label">Available Packages</span>';
        final os = web.document.createElement("div");
        os.className = "v-options";

        final catalog = SchemaExtractor.getFirst(p['hasOfferCatalog']);
        final elements = SchemaExtractor.getArray(catalog is Map ? catalog['itemListElement'] : null);

        for (final off in elements) {
          if (off is! Map) continue;
          final btn = web.document.createElement("button") as web.HTMLButtonElement;
          btn.className = "v-btn";
          final itemOffered = off['itemOffered'];
          final itemName = SchemaExtractor.getFirst(itemOffered is Map ? itemOffered['name'] : null) ?? SchemaExtractor.getFirst(off['name']);
          final itemPrice = SchemaExtractor.getFirst(off['price']);
          final itemCurrency = SchemaExtractor.getFirst(off['priceCurrency']);

          btn.innerHTML = '$itemName<br/><small>${itemCurrency ?? "INR"} $itemPrice</small>';
          btn.onclick = ((web.MouseEvent e) {
            state.selectedPackage = off;
            final symbol = SchemaExtractor.getCurrencySymbol(SchemaExtractor.getFirst(off['priceCurrency'])?.toString() ?? 'INR');
            UIManager.setContent('p-price', '$symbol${SchemaExtractor.getFirst(off['price'])}');
            _renderQuantityConstraints(off);

            final btns = web.document.querySelectorAll('.v-btn');
            for (int i = 0; i < btns.length; i++) {
              final b = btns.item(i) as web.Element?;
              b?.classList.remove('active');
            }
            btn.classList.add('active');
          }).toJS;

          os.appendChild(btn);
        }

        g.appendChild(os);
        vc.appendChild(g);
      }
    }

    final variantBtns = web.document.querySelectorAll(".v-btn[data-attr]");
    for (int i = 0; i < variantBtns.length; i++) {
      final btn = variantBtns.item(i) as web.HTMLElement?;
      if (btn != null) {
        final a = btn.getAttribute("data-attr") ?? '';
        final vL = btn.getAttribute("data-val") ?? btn.textContent;
        UIManager.toggleClass('.v-btn[data-attr="$a"][data-val="$vL"]', 'active', state.selectedVariants[a] == vL);
      }
    }

    _checkAvailability(p, state);
  }

  void _checkAvailability(Map p, AppState state) {
    final variants = SchemaExtractor.getArray(p['hasVariant']);
    if (variants.isEmpty) return;

    final variantBtns = web.document.querySelectorAll('.v-btn[data-attr]');
    for (int i = 0; i < variantBtns.length; i++) {
      final btn = variantBtns.item(i) as web.HTMLElement?;
      if (btn != null) {
        final a = btn.getAttribute('data-attr') ?? '';
        final v = btn.getAttribute('data-val') ?? '';
        final test = {...state.selectedVariants, a: v};

        dynamic match;
        for (final x in variants) {
          if (x is! Map) continue;
          bool allMatch = true;
          for (final entry in test.entries) {
            final fieldVal = SchemaExtractor.getFirst(x[entry.key]);
            if (fieldVal != null && fieldVal.toString() != entry.value) {
              allMatch = false;
              break;
            }
          }
          if (allMatch) {
            match = x;
            break;
          }
        }

        final availability = match is Map ? SchemaExtractor.extractAvailability(match['offers']) : null;
        final out = availability == 'https://schema.org/OutOfStock';
        btn.style.opacity = match == null ? '0.3' : (out ? '0.6' : '1');
        btn.style.borderStyle = match == null ? 'dashed' : 'solid';
      }
    }
  }

  void _renderSpecs(Map variant, Map p) {
    final sp = UIManager.el("p-specs");
    final sl = UIManager.el("specs-list");
    if (sp != null && sl != null) {
      String? getVal(dynamic v) {
        if (v == null) return null;
        if (v is String) return v;
        if (v is num) return v.toString();
        if (v is Map) {
          return SchemaExtractor.getFirst(v['name'])?.toString() ??
              SchemaExtractor.getFirst(v['value'])?.toString() ??
              SchemaExtractor.getFirst(v['text'])?.toString();
        }
        return null;
      }

      final flds = <String, String?>{
        'SKU': getVal(variant['sku'] ?? p['sku']),
        'MPN': getVal(variant['mpn'] ?? p['mpn']),
        'Model': getVal(variant['model'] ?? p['model']),
        'Brand': getVal(variant['brand'] ?? p['brand']),
        'Manufacturer': getVal(variant['manufacturer'] ?? p['manufacturer']),
        'Material': getVal(variant['material'] ?? p['material']),
        'Pattern': getVal(variant['pattern'] ?? p['pattern']),
        'GTIN': (variant['gtin13'] ?? variant['gtin8'] ?? variant['gtin14'] ?? variant['gtin'] ?? '').toString(),
        'Weight': getVal(variant['weight'] ?? p['weight']),
      };

      String h = '';
      for (final entry in flds.entries) {
        if (entry.value != null && entry.value!.isNotEmpty) {
          h += '<div style="display:flex;justify-content:space-between;padding:10px 0;border-bottom:1px solid rgba(0,0,0,0.05);"><span style="opacity:0.6;">${entry.key}</span><span style="font-weight:700;">${entry.value}</span></div>';
        }
      }

      final addProps = [
        ...SchemaExtractor.getArray(p['additionalProperty']),
        ...SchemaExtractor.getArray(variant['additionalProperty'])
      ];

      for (final prop in addProps) {
        if (prop is Map) {
          final name = SchemaExtractor.getFirst(prop['name']);
          final val = SchemaExtractor.getFirst(prop['value']);
          if (name != null && val != null) {
            h += '<div style="display:flex;justify-content:space-between;padding:10px 0;border-bottom:1px solid rgba(0,0,0,0.05);"><span style="opacity:0.6;">$name</span><span style="font-weight:700;">$val</span></div>';
          }
        }
      }

      if (h.isNotEmpty) {
        (sp as web.HTMLElement).style.display = "block";
        sl.innerHTML = h;
      } else {
        (sp as web.HTMLElement).style.display = "none";
      }
    }
  }

  void renderSeller(dynamic s) {
    final box = UIManager.el("p-seller");
    final inf = UIManager.el("seller-info");
    final maps = UIManager.el("maps-link") as web.HTMLAnchorElement?;
    if (box == null || inf == null) return;
    if (s == null) {
      (box as web.HTMLElement).style.display = "none";
      return;
    }
    (box as web.HTMLElement).style.display = "block";

    final openStatus = SchemaExtractor.isBusinessOpen(s);
    final isOpen = openStatus['isOpen'] == true;
    final message = openStatus['message']?.toString();

    final statusHtml = isOpen
        ? '<span class="stock-badge in-stock" style="margin:0 0 10px 0;">Open Now</span>'
        : '<span class="stock-badge out-stock" style="margin:0 0 10px 0;">${message ?? 'Currently Closed'}</span>';

    final addBtn = UIManager.el("add-to-cart-btn") as web.HTMLButtonElement?;
    if (addBtn != null && !isOpen) {
      addBtn.disabled = true;
      addBtn.textContent = message ?? "Seller Currently Closed";
    }

    final sMap = s is Map ? s : {};
    final alternateName = SchemaExtractor.getFirst(sMap['alternateName']);
    final name = SchemaExtractor.getFirst(sMap['name'])?.toString() ?? "Antinna";
    final displayName = alternateName != null ? "$name ($alternateName)" : name;

    final address = SchemaExtractor.getFirst(sMap['address']);

    final phone = SchemaExtractor.getFirst(sMap['telephone']);
    final phoneHtml = phone != null ? '&#128222; <a href="tel:$phone" style="color:inherit; text-decoration:none;">$phone</a><br/>' : "";
    final email = SchemaExtractor.getFirst(sMap['email']);

    String addrStr = "";
    if (address is Map) {
      addrStr = "📍 ${SchemaExtractor.getFirst(address['streetAddress']) ?? ""}, ${SchemaExtractor.getFirst(address['addressLocality']) ?? ""}";
    }

    inf.innerHTML = '$statusHtml<br/><strong>$displayName</strong><br/>$phoneHtml${email != null ? '&#128231; <a href="mailto:$email">$email</a><br/>' : ""}$addrStr';
    if (maps != null) {
      final geo = SchemaExtractor.getFirst(sMap['geo']);
      final hasMap = SchemaExtractor.getFirst(sMap['hasMap']);
      if (hasMap != null || geo != null) {
        maps.style.display = "inline-flex";
        maps.href = hasMap?.toString() ?? (geo is Map ? "https://www.google.com/maps/search/?api=1&query=${geo['latitude']},${geo['longitude']}" : "");
      } else {
        maps.style.display = "none";
      }
    }
  }

  void _renderOtherServices(dynamic s, Map p, AppState state) {
    final otherSec = UIManager.el("other-services");
    final otherList = UIManager.el("other-services-list");
    if (otherSec == null || otherList == null) return;

    final sMap = s is Map ? s : {};
    final catalog = SchemaExtractor.getArray(sMap['hasOfferCatalog'] ?? p['hasOfferCatalog']);
    final List services = [];
    for (final cat in catalog) {
      if (cat is Map) services.addAll(SchemaExtractor.getArray(cat['itemListElement']));
    }

    final addOns = SchemaExtractor.getArray(p['addOn'] ?? sMap['addOn']);
    _renderAddOns(addOns, s, p, state);

    if (services.isNotEmpty) {
      (otherSec as web.HTMLElement).style.display = "block";

      otherList.innerHTML = services.map((ser) {
        if (ser is! Map) return '';
        final rawItem = SchemaExtractor.getFirst(ser['itemOffered']) ?? ser;
        final n = SchemaExtractor.getFirst(rawItem is Map ? rawItem['name'] : null) ?? SchemaExtractor.getFirst(ser['name']);
        final priceData = SchemaExtractor.extractPrice(ser);
        final symbol = SchemaExtractor.getCurrencySymbol(priceData['currency']!);

        final currentUrl = web.window.location.href.split('?')[0].split('#')[0];
        final limits = SchemaExtractor.extractEligibleQuantity(ser);
        final minValue = limits['minValue'];
        final maxValue = limits['maxValue'];
        final inventoryLevel = SchemaExtractor.extractInventoryLevel(ser['offers'] ?? ser);

        final itemWithUrl = {
          ...(rawItem is Map ? rawItem : {}),
          'name': n,
          '@type': (rawItem is Map ? rawItem['@type'] : null) ?? ser['@type'] ?? 'Service',
          'url': currentUrl,
          'offers': {
            '@type': 'Offer',
            'price': priceData['price'],
            'priceCurrency': priceData['currency'],
            'availability': SchemaExtractor.extractAvailability(ser),
            'eligibleQuantity': (minValue != null || maxValue != null) ? {'@type': 'QuantitativeValue', 'minValue': minValue, 'maxValue': maxValue} : null,
            'inventoryLevel': inventoryLevel != null ? {'@type': 'QuantitativeValue', 'value': inventoryLevel} : null
          }
        };

        final itemJson = jsonEncode(itemWithUrl).replaceAll("'", "&apos;");
        final sellerJson = s != null ? jsonEncode(s).replaceAll("'", "&apos;") : "''";

        return '<div class="h-card"><div style="font-weight:700;margin-bottom:10px;height:3em;overflow:hidden;">$n</div><div class="price" style="font-size:1.2rem;margin-bottom:15px;">${priceData['price'] != "0" ? "$symbol${priceData['price']}" : 'Free/Included'}</div><button class="v-btn" style="width:100%;padding:10px;font-size:0.85rem;" onclick="cartAddServiceItem(\'$itemJson\', \'$sellerJson\')">Add Service</button></div>';
      }).join('');
    } else {
      (otherSec as web.HTMLElement).style.display = "none";
    }
  }

  void _renderAddOns(List addOns, dynamic s, Map p, AppState state) {
    var addonSec = UIManager.el("addon-services");
    if (addonSec == null) {
      addonSec = web.document.createElement('div');
      addonSec.id = "addon-services";
      addonSec.className = "details-card";
      (addonSec as web.HTMLElement).style.marginTop = "20px";
      addonSec.innerHTML = '<h2 class="section-title">Addons</h2><div id="addon-services-list" class="h-list"></div>';
      UIManager.el("other-services")?.before(addonSec);
    }

    final list = UIManager.el("addon-services-list");
    if (list == null) return;

    if (addOns.isEmpty) {
      (addonSec as web.HTMLElement).style.display = "none";
      return;
    }

    (addonSec as web.HTMLElement).style.display = "block";

    final win = web.window as dynamic;
    final cartManager = win.CartManager;
    final currentUrl = web.window.location.href.split('?')[0].split('#')[0];

    String parentKey = '';
    bool isParentInCart = false;

    if (cartManager != null) {
      final pMapWithUrl = {...p, 'url': currentUrl};
      parentKey = cartManager.generateItemKey(pMapWithUrl, state.selectedVariants)?.toString() ?? '';
      final order = cartManager.getOrder();
      final orderedItems = SchemaExtractor.getArray(order is Map ? order['orderedItem'] : null);
      isParentInCart = orderedItems.any((oi) => oi is Map && oi['itemKey'] == parentKey);
    }

    list.innerHTML = addOns.map((ser) {
      if (ser is! Map) return '';
      final rawItem = SchemaExtractor.getFirst(ser['itemOffered']) ?? ser;
      final n = SchemaExtractor.getFirst(rawItem is Map ? rawItem['name'] : null) ?? SchemaExtractor.getFirst(ser['name']);
      final priceData = SchemaExtractor.extractPrice(ser);
      final symbol = SchemaExtractor.getCurrencySymbol(priceData['currency']!);

      final limits = SchemaExtractor.extractEligibleQuantity(ser);
      final minValue = limits['minValue'];
      final maxValue = limits['maxValue'];
      final inventoryLevel = SchemaExtractor.extractInventoryLevel(ser['offers'] ?? ser);

      final itemWithUrl = {
        ...(rawItem is Map ? rawItem : {}),
        'name': n,
        '@type': (rawItem is Map ? rawItem['@type'] : null) ?? ser['@type'] ?? 'Service',
        'offers': {
          '@type': 'Offer',
          'price': priceData['price'],
          'priceCurrency': priceData['currency'],
          'availability': SchemaExtractor.extractAvailability(ser),
          'eligibleQuantity': (minValue != null || maxValue != null) ? {'@type': 'QuantitativeValue', 'minValue': minValue, 'maxValue': maxValue} : null,
          'inventoryLevel': inventoryLevel != null ? {'@type': 'QuantitativeValue', 'value': inventoryLevel} : null
        }
      };

      final itemJson = jsonEncode(itemWithUrl).replaceAll("'", "&apos;");

      return '''
        <div class="h-card" style="opacity: ${isParentInCart ? '1' : '0.5'}">
            <div style="font-weight:700;margin-bottom:10px;height:3em;overflow:hidden;">$n</div>
            <div class="price" style="font-size:1.2rem;margin-bottom:15px;">$symbol${priceData['price']}</div>
            <button class="v-btn ${isParentInCart ? 'active' : ''}" style="width:100%;padding:10px;font-size:0.85rem;"
                ${isParentInCart ? '' : 'disabled'}
                onclick="cartAddAddOn('$parentKey', '$itemJson')">
                ${isParentInCart ? 'Add Addon' : 'Add Base Product First'}
            </button>
        </div>''';
    }).join('');
  }
}
