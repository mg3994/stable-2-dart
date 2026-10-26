import 'package:web/web.dart' as web;
import 'dart:convert';
import 'schema_extractor.dart';

class CartManager {
  Map<String, dynamic> _order = {};
  final String _storageKey = "antinna_cart_order";

  CartManager() {
    _order = _loadFromStorage() ?? {
      "@type": "Order",
      "orderedItem": [],
      "totalPrice": 0,
      "priceCurrency": "INR",
    };
    _deduplicate();
  }

  Map<String, dynamic>? _loadFromStorage() {
    final data = web.window.localStorage.getItem(_storageKey);
    if (data == null || data.isEmpty) return null;
    try {
      return jsonDecode(data) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  void _saveToStorage() {
    _calculateTotal();
    web.window.localStorage.setItem(_storageKey, jsonEncode(_order));
  }

  void _deduplicate() {
    final Map<String, dynamic> uniqueItems = {};
    final List<dynamic> newOrderedItems = [];
    final orderedItems = SchemaExtractor.getArray(_order['orderedItem']);

    for (final item in orderedItems) {
      if (item is! Map<String, dynamic>) continue;
      final key = item['itemKey'] ?? generateItemKey(item['orderedItem'], (item['_selectedVariants'] as Map?)?.cast<String, String>());
      if (uniqueItems.containsKey(key)) {
        uniqueItems[key]['orderQuantity'] = (uniqueItems[key]['orderQuantity'] as num) + (item['orderQuantity'] as num? ?? 1);
      } else {
        item['itemKey'] = key;
        uniqueItems[key] = item;
        newOrderedItems.add(item);
      }
    }

    _order['orderedItem'] = newOrderedItems;
    _calculateTotal();
  }

  void _calculateTotal() {
    final orderedItems = SchemaExtractor.getArray(_order['orderedItem']);
    double total = 0.0;

    for (final item in orderedItems) {
      if (item is! Map) continue;
      if (!isItemOrderable(item)) continue;
      final qty = (item['orderQuantity'] as num? ?? 1).toInt();
      final orderedItem = item['orderedItem'];
      final offers = orderedItem is Map ? orderedItem['offers'] : null;
      final priceMap = SchemaExtractor.extractPriceForQuantity(offers, qty);
      double itemTotal = (double.tryParse(priceMap['price'] ?? '0') ?? 0.0) * qty;

      // Add price of addons
      final addOns = SchemaExtractor.getArray(item['addOns']);
      for (final addon in addOns) {
        if (addon is! Map) continue;
        final addonQty = (addon['orderQuantity'] as num? ?? 0).toInt();
        final addonOrderedItem = addon['orderedItem'];
        final addonOffers = addonOrderedItem is Map ? addonOrderedItem['offers'] : null;
        final addonPriceMap = SchemaExtractor.extractPriceForQuantity(addonOffers, addonQty);
        itemTotal += (double.tryParse(addonPriceMap['price'] ?? '0') ?? 0.0) * addonQty;
      }

      total += itemTotal;
    }

    _order['totalPrice'] = total;
  }

  bool isItemOrderable(dynamic item) {
    if (item is! Map) return false;
    if (item['isUnavailable'] == true) return false;
    final orderedItem = item['orderedItem'];
    final offers = orderedItem is Map ? orderedItem['offers'] : null;
    final av = SchemaExtractor.extractAvailability(offers);
    if (av == "https://schema.org/OutOfStock" || av == "https://schema.org/SoldOut") return false;
    return true;
  }

  bool isItemQuantityValid(dynamic item) {
    if (item is! Map) return false;
    final constraints = item['_constraints'];
    final min = constraints is Map ? constraints['minValue'] : null;
    if (min != null && (item['orderQuantity'] as num? ?? 1) < (min as num)) return false;
    return true;
  }

  bool isCartValid() {
    final items = SchemaExtractor.getArray(_order['orderedItem']);
    if (items.isEmpty) return false;
    return items.every((item) => isItemOrderable(item) && isItemQuantityValid(item));
  }

  String? addItem(dynamic item, [dynamic seller, Map<String, String>? selectedVariants, int quantity = 1]) {
    final offers = item is Map ? item['offers'] : null;
    final availability = SchemaExtractor.extractAvailability(offers);
    if (availability == "https://schema.org/OutOfStock") {
      return null;
    }

    if (item is Map && SchemaExtractor.getFirst(item['url']) == null) {
      item['url'] = web.window.location.href.split('?')[0].split('#')[0];
    }

    final itemKey = generateItemKey(item, selectedVariants);
    final orderedItems = SchemaExtractor.getArray(_order['orderedItem']);

    dynamic existing;
    for (final oi in orderedItems) {
      if (oi is Map && oi['itemKey'] == itemKey) {
        existing = oi;
        break;
      }
    }

    final limits = SchemaExtractor.extractEligibleQuantity(item);
    final minValue = limits['minValue'];
    final maxValue = limits['maxValue'];
    final inventoryLevel = SchemaExtractor.extractInventoryLevel(offers ?? item);
    final effectiveMax = (maxValue != null && inventoryLevel != null)
        ? (maxValue < inventoryLevel ? maxValue : inventoryLevel)
        : (maxValue ?? inventoryLevel);

    final initialQty = (quantity < (minValue ?? 1)) ? (minValue ?? 1) : quantity;

    if (existing != null) {
      final currentQty = (existing['orderQuantity'] as num? ?? 0).toInt();
      final newQty = currentQty + quantity;

      if (effectiveMax != null && newQty > effectiveMax) {
        _showToast("Maximum limit of $effectiveMax reached for this item", "error");
        existing['orderQuantity'] = effectiveMax;
      } else {
        existing['orderQuantity'] = newQty;
      }
      _saveToStorage();
      return itemKey;
    } else {
      final itemCopy = jsonDecode(jsonEncode(item));

      final finalInitialQty = effectiveMax != null ? (initialQty > effectiveMax ? effectiveMax : initialQty) : initialQty;

      orderedItems.add({
        "@type": "OrderItem",
        "orderedItem": {
          ...(itemCopy is Map ? itemCopy : {}),
          "url": item is Map ? item['url'] : null,
          "_selectedVariants": selectedVariants != null ? Map<String, String>.from(selectedVariants) : null,
        },
        "orderQuantity": finalInitialQty,
        "seller": seller != null ? jsonDecode(jsonEncode(seller)) : null,
        "itemKey": itemKey,
        "_constraints": {"minValue": minValue, "maxValue": maxValue, "inventoryLevel": inventoryLevel},
        "addOns": []
      });
      _order['orderedItem'] = orderedItems;
      _saveToStorage();
      return itemKey;
    }
  }

  void addAddOn(String parentItemKey, dynamic addon, [int quantity = 1]) {
    final orderedItems = SchemaExtractor.getArray(_order['orderedItem']);
    dynamic parent;
    for (final oi in orderedItems) {
      if (oi is Map && oi['itemKey'] == parentItemKey) {
        parent = oi;
        break;
      }
    }

    if (parent == null) {
      _showToast("Please add the main product first", "error");
      return;
    }

    if (parent['addOns'] == null || parent['addOns'] is! List) {
      parent['addOns'] = [];
    }

    final addonKey = generateItemKey(addon);
    final List addOns = parent['addOns'];
    dynamic existing;
    for (final a in addOns) {
      if (a is Map && a['itemKey'] == addonKey) {
        existing = a;
        break;
      }
    }

    if (existing != null) {
      final limits = getAddOnLimits(parent, existing);
      final newQty = (existing['orderQuantity'] as num? ?? 0).toInt() + quantity;
      if (limits['maxValue'] != null && newQty > limits['maxValue']!) {
        existing['orderQuantity'] = limits['maxValue'];
      } else {
        existing['orderQuantity'] = newQty;
      }
    } else {
      final limits = SchemaExtractor.extractEligibleQuantity(addon);
      final minValue = limits['minValue'];
      final maxValue = limits['maxValue'];
      final offers = addon is Map ? addon['offers'] : null;
      final inventoryLevel = SchemaExtractor.extractInventoryLevel(offers ?? addon);
      final tempAddon = {
        "orderedItem": jsonDecode(jsonEncode(addon)),
        "_constraints": {"minValue": minValue, "maxValue": maxValue, "inventoryLevel": inventoryLevel}
      };
      final dynamicLimits = getAddOnLimits(parent, tempAddon);

      final minReq = dynamicLimits['minValue'] ?? 1;
      addOns.add({
        "orderedItem": tempAddon['orderedItem'],
        "orderQuantity": quantity < minReq ? minReq : quantity,
        "itemKey": addonKey,
        "_constraints": {"minValue": minValue, "maxValue": maxValue, "inventoryLevel": inventoryLevel}
      });
    }
    _saveToStorage();
  }

  Map<String, int?> getAddOnLimits(dynamic parent, dynamic addon) {
    final parentQty = (parent is Map ? parent['orderQuantity'] as num? : null)?.toInt() ?? 1;
    final constraints = addon is Map ? addon['_constraints'] : null;
    final min = constraints is Map ? constraints['minValue'] as int? : null;
    final max = constraints is Map ? constraints['maxValue'] as int? : null;
    final inventoryLevel = constraints is Map ? constraints['inventoryLevel'] as int? : null;

    final scaledMax = max != null ? max * parentQty : null;

    final effectiveMax = (scaledMax != null && inventoryLevel != null)
        ? (scaledMax < inventoryLevel ? scaledMax : inventoryLevel)
        : (scaledMax ?? inventoryLevel);

    return {
      "minValue": min != null ? min * parentQty : null,
      "maxValue": effectiveMax
    };
  }

  String generateItemKey(dynamic item, [Map<String, String>? variants]) {
    if (item == null) return '';
    String url = (item is Map ? SchemaExtractor.getFirst(item['url']) : null)?.toString() ?? '';
    if (url.contains('?')) url = url.split('?')[0];
    if (url.contains('#')) url = url.split('#')[0];
    url = url.toLowerCase().replaceAll(RegExp(r'\/$'), "");

    final type = (item is Map ? SchemaExtractor.getFirst(item['@type']) : null)?.toString() ?? "Product";
    final name = (item is Map ? SchemaExtractor.getFirst(item['name']) : null)?.toString() ?? '';
    final sku = (item is Map ? SchemaExtractor.getFirst(item['sku']) : null)?.toString() ?? '';

    String variantString = '';
    if (variants != null && variants.isNotEmpty) {
      final sortedKeys = variants.keys.toList()..sort();
      variantString = sortedKeys.map((k) => '$k:${variants[k]}').join('|');
    }

    return '$url::$type::$sku::$name::$variantString';
  }

  void removeItem(int index) {
    final orderedItems = SchemaExtractor.getArray(_order['orderedItem']);
    if (index < 0 || index >= orderedItems.length) return;
    orderedItems.removeAt(index);
    _order['orderedItem'] = orderedItems;
    _saveToStorage();
  }

  void updateQty(int index, int delta) {
    final orderedItems = SchemaExtractor.getArray(_order['orderedItem']);
    if (index < 0 || index >= orderedItems.length) return;
    final item = orderedItems[index];
    if (item is! Map) return;

    final oldQty = (item['orderQuantity'] as num? ?? 0).toInt();
    final newQty = oldQty + delta;
    final constraints = item['_constraints'] as Map?;
    final maxValue = constraints?['maxValue'] as int?;
    final inventoryLevel = constraints?['inventoryLevel'] as int?;
    final effectiveMax = (maxValue != null && inventoryLevel != null)
        ? (maxValue < inventoryLevel ? maxValue : inventoryLevel)
        : (maxValue ?? inventoryLevel);

    if (delta > 0 && effectiveMax != null && newQty > effectiveMax) {
      _showToast("Maximum limit of $effectiveMax reached", "error");
      return;
    }

    item['orderQuantity'] = newQty;

    // Proportional scaling of addons
    if (item['addOns'] is List) {
      final oldParentQty = oldQty == 0 ? 1 : oldQty;
      final newParentQty = newQty;

      for (final addon in item['addOns']) {
        if (addon is! Map) continue;
        final ratio = (addon['orderQuantity'] as num? ?? 0) / oldParentQty;
        addon['orderQuantity'] = (ratio * newParentQty).round();

        final limits = getAddOnLimits(item, addon);
        if (limits['maxValue'] != null && (addon['orderQuantity'] as int) > limits['maxValue']!) {
          addon['orderQuantity'] = limits['maxValue'];
        }
        if (limits['minValue'] != null && (addon['orderQuantity'] as int) < limits['minValue']!) {
          addon['orderQuantity'] = limits['minValue'];
        }
      }
    }

    if ((item['orderQuantity'] as int) <= 0) {
      removeItem(index);
    } else {
      _saveToStorage();
    }
  }

  void updateAddOnQty(int parentIndex, int addonIndex, int delta) {
    final orderedItems = SchemaExtractor.getArray(_order['orderedItem']);
    if (parentIndex < 0 || parentIndex >= orderedItems.length) return;
    final parent = orderedItems[parentIndex];
    if (parent is! Map || parent['addOns'] is! List) return;

    final addOns = parent['addOns'] as List;
    if (addonIndex < 0 || addonIndex >= addOns.length) return;
    final addon = addOns[addonIndex];
    if (addon is! Map) return;

    final newQty = (addon['orderQuantity'] as num? ?? 0).toInt() + delta;
    final limits = getAddOnLimits(parent, addon);

    if (delta > 0 && limits['maxValue'] != null && newQty > limits['maxValue']!) {
      _showToast("Maximum limit of ${limits['maxValue']} reached", "error");
      return;
    }

    if (delta < 0 && limits['minValue'] != null && newQty < limits['minValue']!) {
      _showToast("Minimum of ${limits['minValue']} required", "error");
      return;
    }

    addon['orderQuantity'] = newQty;
    if ((addon['orderQuantity'] as int) <= 0) {
      addOns.removeAt(addonIndex);
    }
    _saveToStorage();
  }

  void removeAddOn(int parentIndex, int addonIndex) {
    final orderedItems = SchemaExtractor.getArray(_order['orderedItem']);
    if (parentIndex < 0 || parentIndex >= orderedItems.length) return;
    final parent = orderedItems[parentIndex];
    if (parent is! Map || parent['addOns'] is! List) return;

    final addOns = parent['addOns'] as List;
    if (addonIndex < 0 || addonIndex >= addOns.length) return;
    addOns.removeAt(addonIndex);
    _saveToStorage();
  }

  void updateItemDetails(int index, dynamic freshBaseData) {
    final orderedItems = SchemaExtractor.getArray(_order['orderedItem']);
    if (index < 0 || index >= orderedItems.length) return;
    final item = orderedItems[index];
    if (item is! Map) return;

    if (freshBaseData == null) {
      item['isUnavailable'] = true;
    } else {
      dynamic freshMatch;
      final cartItem = item['orderedItem'];
      final dataSources = freshBaseData is List ? freshBaseData : [freshBaseData];

      final normalizedCartName = SchemaExtractor.normalizeName(cartItem is Map ? cartItem['name']?.toString() ?? '' : '');

      for (final source in dataSources) {
        final allServices = SchemaExtractor.findAllServices(source);
        for (final serviceOffer in allServices) {
          if (serviceOffer is! Map) continue;
          final serviceItem = serviceOffer['itemOffered'] ?? serviceOffer;
          final name = SchemaExtractor.getFirst(serviceItem['name']) ?? SchemaExtractor.getFirst(serviceOffer['name']);
          if (name != null && SchemaExtractor.normalizeName(name.toString()) == normalizedCartName) {
            freshMatch = serviceOffer;
            break;
          }
        }
        if (freshMatch != null) break;

        if (cartItem is Map && cartItem['@type'] == "Product" && source is Map && source['hasVariant'] != null) {
          final variantMatch = SchemaExtractor.findMatchingVariant(source, (cartItem['_selectedVariants'] as Map?)?.cast<String, String>() ?? {});
          if (variantMatch != null) {
            freshMatch = variantMatch;
            break;
          }
        }

        if (source is Map && cartItem is Map) {
          final sourceId = SchemaExtractor.getFirst(source['sku']) ?? SchemaExtractor.getFirst(source['identifier']) ?? SchemaExtractor.getFirst(source['name']);
          final cartId = SchemaExtractor.getFirst(cartItem['sku']) ?? SchemaExtractor.getFirst(cartItem['identifier']) ?? SchemaExtractor.getFirst(cartItem['name']);
          if (SchemaExtractor.getFirst(source['@type']) == SchemaExtractor.getFirst(cartItem['@type']) && sourceId == cartId) {
            freshMatch = source;
            break;
          }
        }
      }

      if (freshMatch != null) {
        item['isUnavailable'] = false;
        final priceData = SchemaExtractor.extractPrice(freshMatch);
        final availability = SchemaExtractor.extractAvailability(freshMatch);
        final limits = SchemaExtractor.extractEligibleQuantity(freshMatch);
        final minValue = limits['minValue'];
        final maxValue = limits['maxValue'];
        final inventoryLevel = SchemaExtractor.extractInventoryLevel(freshMatch is Map ? (freshMatch['offers'] ?? freshMatch) : freshMatch);

        item['_constraints'] = {"minValue": minValue, "maxValue": maxValue, "inventoryLevel": inventoryLevel};
        if (item['orderedItem'] is Map) {
          item['orderedItem']['offers'] = {
            "@type": "Offer",
            "price": priceData['price'],
            "priceCurrency": priceData['currency'],
            "availability": availability,
            "priceSpecification": freshMatch is Map ? (freshMatch['priceSpecification'] ?? (freshMatch['offers'] is Map ? freshMatch['offers']['priceSpecification'] : null)) : null,
            "eligibleQuantity": (minValue != null || maxValue != null)
                ? {"@type": "QuantitativeValue", "minValue": minValue, "maxValue": maxValue}
                : null
          };

          final matchedItem = freshMatch is Map ? (freshMatch['itemOffered'] ?? freshMatch) : freshMatch;
          if (matchedItem is Map) {
            item['orderedItem']['image'] = matchedItem['image'] ?? item['orderedItem']['image'];
            item['orderedItem']['name'] = matchedItem['name'] ?? item['orderedItem']['name'];
            item['orderedItem']['description'] = matchedItem['description'] ?? item['orderedItem']['description'];
          }
        }

        // Update AddOns
        if (item['addOns'] is List) {
          for (final addon in item['addOns']) {
            if (addon is! Map) continue;
            dynamic addonMatch;
            final addonItem = addon['orderedItem'];
            final normalizedAddonName = SchemaExtractor.normalizeName(addonItem is Map ? addonItem['name']?.toString() ?? '' : '');

            for (final source in dataSources) {
              final allServices = SchemaExtractor.findAllServices(source);
              for (final serviceOffer in allServices) {
                if (serviceOffer is! Map) continue;
                final sItem = serviceOffer['itemOffered'] ?? serviceOffer;
                final sName = SchemaExtractor.getFirst(sItem['name']) ?? SchemaExtractor.getFirst(serviceOffer['name']);
                if (sName != null && SchemaExtractor.normalizeName(sName.toString()) == normalizedAddonName) {
                  addonMatch = serviceOffer;
                  break;
                }
              }
              if (addonMatch != null) break;
            }

            if (addonMatch != null) {
              final aPriceData = SchemaExtractor.extractPrice(addonMatch);
              final aAvailability = SchemaExtractor.extractAvailability(addonMatch);
              final aLimits = SchemaExtractor.extractEligibleQuantity(addonMatch);
              final aMin = aLimits['minValue'];
              final aMax = aLimits['maxValue'];
              final aInv = SchemaExtractor.extractInventoryLevel(addonMatch is Map ? (addonMatch['offers'] ?? addonMatch) : addonMatch);

              addon['_constraints'] = {"minValue": aMin, "maxValue": aMax, "inventoryLevel": aInv};
              if (addon['orderedItem'] is Map) {
                addon['orderedItem']['offers'] = {
                  "@type": "Offer",
                  "price": aPriceData['price'],
                  "priceCurrency": aPriceData['currency'],
                  "availability": aAvailability,
                  "priceSpecification": addonMatch is Map ? (addonMatch['priceSpecification'] ?? (addonMatch['offers'] is Map ? addonMatch['offers']['priceSpecification'] : null)) : null,
                  "eligibleQuantity": (aMin != null || aMax != null) ? {"@type": "QuantitativeValue", "minValue": aMin, "maxValue": aMax} : null,
                  "inventoryLevel": aInv != null ? {"@type": "QuantitativeValue", "value": aInv} : null
                };
              }
            }
          }
        }
      } else {
        item['isUnavailable'] = true;
      }
    }
    _saveToStorage();
  }

  Map<String, dynamic> getOrder() => _order;

  int getTotalQuantity() {
    final orderedItems = SchemaExtractor.getArray(_order['orderedItem']);
    int sum = 0;
    for (final item in orderedItems) {
      if (item is Map) {
        sum += (item['orderQuantity'] as num? ?? 0).toInt();
      }
    }
    return sum;
  }

  List<String> getServiceabilityErrors(dynamic verifiedLocation) {
    final items = SchemaExtractor.getArray(_order['orderedItem']);
    final List<String> errors = [];

    for (final item in items) {
      if (item is! Map) continue;
      final itemOffered = item['orderedItem'];
      final areas = SchemaExtractor.extractAreaServed(itemOffered);

      final double? lat = verifiedLocation is Map ? double.tryParse(verifiedLocation['lat']?.toString() ?? '') : null;
      final double? lon = verifiedLocation is Map ? double.tryParse((verifiedLocation['lon'] ?? verifiedLocation['lng'])?.toString() ?? '') : null;
      final addressDetails = verifiedLocation is Map ? verifiedLocation['addressDetails'] : null;

      if (areas.isNotEmpty) {
        final isServiceable = areas.any((area) => SchemaExtractor.isLocationInArea(lat, lon, addressDetails, area));
        if (!isServiceable) {
          errors.add((itemOffered is Map ? SchemaExtractor.getFirst(itemOffered['name']) : null)?.toString() ?? "An item");
        }
      }

      // Check Business Hours
      final seller = item['seller'];
      if (seller != null) {
        final status = SchemaExtractor.isBusinessOpen(seller);
        if (status['isOpen'] != true) {
          final itemName = (itemOffered is Map ? SchemaExtractor.getFirst(itemOffered['name']) : null)?.toString() ?? "An item";
          errors.add("$itemName (Seller currently closed: ${status['message']})");
        }
      }

      // Check addons
      if (item['addOns'] is List) {
        for (final addon in item['addOns']) {
          if (addon is! Map) continue;
          final addonItem = addon['orderedItem'];
          final aAreas = SchemaExtractor.extractAreaServed(addonItem);
          if (aAreas.isNotEmpty) {
            final isAServiceable = aAreas.any((area) => SchemaExtractor.isLocationInArea(lat, lon, addressDetails, area));
            if (!isAServiceable) {
              errors.add((addonItem is Map ? SchemaExtractor.getFirst(addonItem['name']) : null)?.toString() ?? "An addon");
            }
          }
        }
      }
    }

    return errors;
  }

  int getMaxLeadTime() {
    final items = SchemaExtractor.getArray(_order['orderedItem']);
    int maxLead = 0;

    for (final item in items) {
      if (item is! Map) continue;
      final lead = SchemaExtractor.extractLeadTime(item['orderedItem']);
      if (lead > maxLead) maxLead = lead;

      if (item['addOns'] is List) {
        for (final addon in item['addOns']) {
          if (addon is! Map) continue;
          final aLead = SchemaExtractor.extractLeadTime(addon['orderedItem']);
          if (aLead > maxLead) maxLead = aLead;
        }
      }
    }

    return maxLead;
  }

  void clear() {
    _order['orderedItem'] = [];
    _saveToStorage();
  }

  void _showToast(String message, String type) {
    try {
      final uiManager = (web.window as dynamic).UIManager;
      if (uiManager != null) {
        uiManager.showToast(message, type);
      }
    } catch (_) {}
  }
}
