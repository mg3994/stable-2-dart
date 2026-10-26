import 'dart:math' as math;
import 'dart:js_interop';
import 'package:web/web.dart' as web;
import 'dart:convert';

class SchemaExtractor {
  static dynamic getFirst(dynamic val) {
    if (val is List) {
      return val.isNotEmpty ? val[0] : null;
    }
    return val;
  }

  static List<dynamic> getArray(dynamic val) {
    if (val == null) return [];
    if (val is List) return val;
    return [val];
  }

  static String decodeEntities(String text) {
    if (text.isEmpty) return "";
    final textarea = web.document.createElement("textarea") as web.HTMLTextAreaElement;
    textarea.innerHTML = text;
    String decoded = textarea.value;
    if (decoded.contains("&quot;")) {
      textarea.innerHTML = decoded;
      decoded = textarea.value;
    }
    return decoded;
  }

  static dynamic extractJsonLd(String input) {
    if (input.isEmpty) return null;

    try {
      final regExp = RegExp(r'<script[^>]*type=["' "'" r']application\/ld\+json["' "'" r'][^>]*>([\s\S]*?)<\/script>', caseSensitive: false);
      final match = regExp.firstMatch(input);
      String jsonContent = match != null ? match.group(1)! : input;

      String decoded = decodeEntities(jsonContent);

      final cleaned = decoded
          .replaceAll(RegExp(r'\/\*[\s\S]*?\*\/|([^\\:]|^)\/\/.*$', multiLine: true), r'$1')
          .trim();

      try {
        return jsonDecode(cleaned);
      } catch (e) {
        final objectMatch = RegExp(r'\{[\s\S]*\}').firstMatch(cleaned);
        if (objectMatch != null) {
          try {
            return jsonDecode(objectMatch.group(0)!);
          } catch (_) {}
        }
        return null;
      }
    } catch (e) {
      web.console.error("Failed to extract JSON-LD: $e".toJS);
      return null;
    }
  }

  static dynamic findMatchingVariant(dynamic parent, Map<String, String> selectedAttributes, [String? lastClickedAttr]) {
    if (parent == null) return null;
    final variants = getArray(parent['hasVariant']).isNotEmpty ? getArray(parent['hasVariant']) : [parent];

    dynamic match;
    for (final v in variants) {
      if (v is! Map) continue;
      bool allMatch = true;
      for (final entry in selectedAttributes.entries) {
        if (getFirst(v[entry.key])?.toString() != entry.value) {
          allMatch = false;
          break;
        }
      }
      if (allMatch) {
        match = v;
        break;
      }
    }

    if (match == null && lastClickedAttr != null) {
      for (final v in variants) {
        if (v is! Map) continue;
        if (getFirst(v[lastClickedAttr])?.toString() == selectedAttributes[lastClickedAttr]) {
          match = v;
          break;
        }
      }
    }

    return match ?? variants.first;
  }

  static String normalizeName(String name) {
    return name.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  static dynamic findMatchingServicePackage(dynamic parent, String packageName) {
    final catalogs = getArray(parent is Map ? parent['hasOfferCatalog'] : null);
    if (catalogs.isEmpty) return null;

    final normalizedSearch = normalizeName(packageName);

    for (final catalog in catalogs) {
      if (catalog is! Map) continue;
      final elements = getArray(catalog['itemListElement']);
      for (final off in elements) {
        if (off is! Map) continue;
        final item = off['itemOffered'] ?? off;
        final name = getFirst(item['name']) ?? getFirst(off['name']);
        if (name != null && normalizeName(name.toString()) == normalizedSearch) {
          return off;
        }
      }
    }
    return null;
  }

  static List<dynamic> findAllServices(dynamic obj) {
    final List<dynamic> results = [];
    final List<dynamic> stack = [obj];
    final Set<dynamic> seen = {};

    while (stack.isNotEmpty) {
      final current = stack.removeLast();
      if (current == null || seen.contains(current)) continue;
      if (current is Map || current is List) seen.add(current);

      if (current is Map) {
        if (current.containsKey('hasOfferCatalog')) {
          final catalogs = getArray(current['hasOfferCatalog']);
          for (final cat in catalogs) {
            if (cat is Map) {
              final elements = getArray(cat['itemListElement']);
              results.addAll(elements);
              stack.add(cat);
            }
          }
        }

        if (current.containsKey('addOn')) {
          results.addAll(getArray(current['addOn']));
        }

        for (final entry in current.entries) {
          if (entry.key != 'hasOfferCatalog' && entry.key != 'addOn' && entry.value != null) {
            if (entry.value is Map || entry.value is List) {
              stack.add(entry.value);
            }
          }
        }
      } else if (current is List) {
        stack.addAll(current);
      }
    }
    return results;
  }

  static Map<String, String> extractPrice(dynamic offer) {
    return extractPriceForQuantity(offer, 1);
  }

  static Map<String, String> extractPriceForQuantity(dynamic offer, int quantity) {
    final off = offer is List ? (offer.isNotEmpty ? offer[0] : null) : offer;
    if (off == null || off is! Map) return {"price": "0", "currency": "INR"};

    final specs = getArray(
      off['priceSpecification'] ??
      (getArray(off['itemOffered']).isNotEmpty && getArray(off['itemOffered'])[0] is Map ? (getArray(off['itemOffered'])[0]['offers'] is Map ? getArray(off['itemOffered'])[0]['offers']['priceSpecification'] : null) : null) ??
      (getArray(off['offers']).isNotEmpty && getArray(off['offers'])[0] is Map ? getArray(off['offers'])[0]['priceSpecification'] : null) ??
      (getArray(off['offers']).isNotEmpty && getArray(off['offers'])[0] is Map && getArray(off['offers'])[0]['itemOffered'] is Map && getArray(off['offers'])[0]['itemOffered']['offers'] is Map ? getArray(off['offers'])[0]['itemOffered']['offers']['priceSpecification'] : null)
    );

    if (specs.isNotEmpty) {
      dynamic matchingSpec;
      for (final spec in specs) {
        if (spec is! Map) continue;
        if (getFirst(spec['@type']) != "UnitPriceSpecification") continue;
        final eq = getFirst(spec['eligibleQuantity']);
        if (eq == null || eq is! Map) {
          matchingSpec = spec;
          break;
        }

        final min = getFirst(eq['minValue']);
        final max = getFirst(eq['maxValue']);

        final double minVal = min != null ? (num.tryParse(min.toString())?.toDouble() ?? 0.0) : 0.0;
        final double maxVal = max != null ? (num.tryParse(max.toString())?.toDouble() ?? double.infinity) : double.infinity;

        if (quantity >= minVal && quantity <= maxVal) {
          matchingSpec = spec;
          break;
        }
      }

      if (matchingSpec != null) {
        final price = getFirst(matchingSpec['price']) ?? "0";
        final currency = getFirst(matchingSpec['priceCurrency']) ?? "INR";
        return {"price": price.toString(), "currency": currency.toString()};
      }
    }

    final price = getFirst(off['price']) ??
        getFirst(getArray(off['itemOffered']).isNotEmpty && getArray(off['itemOffered'])[0] is Map && getArray(off['itemOffered'])[0]['offers'] is Map ? getArray(off['itemOffered'])[0]['offers']['price'] : null) ??
        getFirst(getArray(off['offers']).isNotEmpty && getArray(off['offers'])[0] is Map ? getArray(off['offers'])[0]['price'] : null) ??
        "0";

    final currency = getFirst(off['priceCurrency']) ??
        getFirst(getArray(off['itemOffered']).isNotEmpty && getArray(off['itemOffered'])[0] is Map && getArray(off['itemOffered'])[0]['offers'] is Map ? getArray(off['itemOffered'])[0]['offers']['priceCurrency'] : null) ??
        getFirst(getArray(off['offers']).isNotEmpty && getArray(off['offers'])[0] is Map ? getArray(off['offers'])[0]['priceCurrency'] : null) ??
        "INR";

    return {"price": price.toString(), "currency": currency.toString()};
  }

  static String extractAvailability(dynamic offer) {
    final off = offer is List ? (offer.isNotEmpty ? offer[0] : null) : offer;
    if (off == null || off is! Map) return "https://schema.org/InStock";

    final av = getFirst(off['availability']) ??
        getFirst(getArray(off['itemOffered']).isNotEmpty && getArray(off['itemOffered'])[0] is Map && getArray(off['itemOffered'])[0]['offers'] is Map ? getArray(off['itemOffered'])[0]['offers']['availability'] : null) ??
        getFirst(getArray(off['offers']).isNotEmpty && getArray(off['offers'])[0] is Map ? getArray(off['offers'])[0]['availability'] : null) ??
        "https://schema.org/InStock";

    if (av is Map && av.containsKey('@id')) {
      return av['@id'].toString();
    }
    return av.toString();
  }

  static Map<String, int?> extractEligibleQuantity(dynamic data) {
    final obj = data is List ? (data.isNotEmpty ? data[0] : null) : data;
    if (obj == null || obj is! Map) return {"minValue": null, "maxValue": null};

    final eq = getFirst(obj['eligibleQuantity']) ??
        getFirst(getArray(obj['itemOffered']).isNotEmpty && getArray(obj['itemOffered'])[0] is Map && getArray(obj['itemOffered'])[0]['offers'] is Map ? getArray(obj['itemOffered'])[0]['offers']['eligibleQuantity'] : null) ??
        getFirst(getArray(obj['itemOffered']).isNotEmpty && getArray(obj['itemOffered'])[0] is Map ? getArray(obj['itemOffered'])[0]['eligibleQuantity'] : null) ??
        getFirst(getArray(obj['offers']).isNotEmpty && getArray(obj['offers'])[0] is Map ? getArray(obj['offers'])[0]['eligibleQuantity'] : null) ??
        getFirst(getArray(obj['offers']).isNotEmpty && getArray(obj['offers'])[0] is Map && getArray(obj['offers'])[0]['itemOffered'] is Map ? getArray(obj['offers'])[0]['itemOffered']['eligibleQuantity'] : null);

    if (eq == null || eq is! Map) return {"minValue": null, "maxValue": null};

    final min = getFirst(eq['minValue']);
    final max = getFirst(eq['maxValue']);

    return {
      "minValue": min != null ? int.tryParse(min.toString()) : null,
      "maxValue": max != null ? int.tryParse(max.toString()) : null
    };
  }

  static int? extractInventoryLevel(dynamic data) {
    final obj = data is List ? (data.isNotEmpty ? data[0] : null) : data;
    if (obj == null || obj is! Map) return null;

    final il = getFirst(obj['inventoryLevel']) ??
        getFirst(getArray(obj['itemOffered']).isNotEmpty && getArray(obj['itemOffered'])[0] is Map && getArray(obj['itemOffered'])[0]['offers'] is Map ? getArray(obj['itemOffered'])[0]['offers']['inventoryLevel'] : null) ??
        getFirst(getArray(obj['itemOffered']).isNotEmpty && getArray(obj['itemOffered'])[0] is Map ? getArray(obj['itemOffered'])[0]['inventoryLevel'] : null) ??
        getFirst(getArray(obj['offers']).isNotEmpty && getArray(obj['offers'])[0] is Map ? getArray(obj['offers'])[0]['inventoryLevel'] : null) ??
        getFirst(getArray(obj['offers']).isNotEmpty && getArray(obj['offers'])[0] is Map && getArray(obj['offers'])[0]['itemOffered'] is Map ? getArray(obj['offers'])[0]['itemOffered']['inventoryLevel'] : null);

    if (il == null) return null;

    final val = il is Map ? getFirst(il['value']) : il;
    return val != null ? int.tryParse(val.toString()) : null;
  }

  static Map<String, double?> extractDimensions(dynamic data) {
    final obj = data is List ? (data.isNotEmpty ? data[0] : null) : data;
    if (obj == null || obj is! Map) return {"weight": null, "height": null, "width": null, "depth": null};

    double? getNum(dynamic v) {
      if (v == null) return null;
      if (v is Map) {
        final val = getFirst(v['value']);
        return val != null ? double.tryParse(val.toString()) : null;
      }
      return double.tryParse(v.toString());
    }

    return {
      "weight": getNum(obj['weight']),
      "height": getNum(obj['height']),
      "width": getNum(obj['width']),
      "depth": getNum(obj['depth'])
    };
  }

  static String? extractAdvanceBookingRequirement(dynamic offer) {
    final off = offer is List ? (offer.isNotEmpty ? offer[0] : null) : offer;
    if (off == null || off is! Map) return null;

    final abr = getFirst(off['advanceBookingRequirement']);
    if (abr == null) return null;

    if (abr is String) return abr;

    if (abr is Map) {
      final val = getFirst(abr['value']);
      final unit = getFirst(abr['unitCode']) ?? getFirst(abr['unitText']) ?? "";

      if (val == null) return null;

      String unitLabel = unit.toString();
      if (unit == 'HUR') unitLabel = 'Hours';
      if (unit == 'DAY') unitLabel = 'Days';

      return "$val $unitLabel".trim();
    }

    return null;
  }

  static String getCurrencySymbol(String currency) {
    final symbols = {
      'INR': '₹',
      'USD': '\$',
      'EUR': '€',
      'GBP': '£',
      'JPY': '¥'
    };
    return symbols[currency.toUpperCase()] ?? currency;
  }

  static String? extractCondition(dynamic data) {
    final obj = data is List ? (data.isNotEmpty ? data[0] : null) : data;
    if (obj == null || obj is! Map) return null;

    final itemOfferedFirst = getArray(obj['itemOffered']).isNotEmpty && getArray(obj['itemOffered'])[0] is Map ? getArray(obj['itemOffered'])[0] : null;
    final offersFirst = getArray(obj['offers']).isNotEmpty && getArray(obj['offers'])[0] is Map ? getArray(obj['offers'])[0] : null;

    final cond = getFirst(obj['itemCondition']) ??
        getFirst(itemOfferedFirst != null && itemOfferedFirst['offers'] is Map ? itemOfferedFirst['offers']['itemCondition'] : null) ??
        getFirst(itemOfferedFirst != null ? itemOfferedFirst['itemCondition'] : null) ??
        getFirst(offersFirst != null ? offersFirst['itemCondition'] : null) ??
        getFirst(offersFirst != null && offersFirst['itemOffered'] is Map ? offersFirst['itemOffered']['itemCondition'] : null);

    if (cond == null) return null;

    final str = cond.toString().toLowerCase();
    if (str.contains("newcondition")) return "New";
    if (str.contains("refurbishedcondition")) return "Refurbished";
    if (str.contains("usedcondition")) return "Used";
    if (str.contains("damagedcondition")) return "Damaged";

    return str.split('/').last;
  }

  static List<dynamic> extractAreaServed(dynamic data) {
    final List<dynamic> results = [];
    final List<dynamic> stack = [data];
    final Set<dynamic> seen = {};

    while (stack.isNotEmpty) {
      final current = stack.removeLast();
      if (current == null || current is! Map || seen.contains(current)) continue;
      seen.add(current);

      final areas = getArray(current['areaServed'] ?? current['eligibleRegion']);
      if (areas.isNotEmpty) {
        results.addAll(areas);
      }

      if (current.containsKey('itemOffered')) stack.add(current['itemOffered']);
      if (current.containsKey('offers')) stack.addAll(getArray(current['offers']));
      if (current.containsKey('hasVariant')) stack.addAll(getArray(current['hasVariant']));
      if (current.containsKey('hasOfferCatalog')) stack.addAll(getArray(current['hasOfferCatalog']));
      if (current.containsKey('itemListElement')) stack.addAll(getArray(current['itemListElement']));
    }

    return results;
  }

  static Map<String, dynamic> isBusinessOpen(dynamic data) {
    final obj = data is List ? (data.isNotEmpty ? data[0] : null) : data;
    if (obj == null || obj is! Map) return {"isOpen": true, "message": null};

    final now = DateTime.now();
    final todayStr = now.toIso8601String().split('T')[0];
    final timeStr = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
    final dayNames = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"];
    final todayName = dayNames[now.weekday % 7];

    // 1. Check Special Opening Hours (Overrides)
    final special = getArray(obj['specialOpeningHoursSpecification']);
    for (final s in special) {
      if (s is! Map) continue;
      final from = getFirst(s['validFrom']);
      final through = getFirst(s['validThrough']);
      if (from != null && through != null && todayStr.compareTo(from.toString()) >= 0 && todayStr.compareTo(through.toString()) <= 0) {
        final opens = getFirst(s['opens'])?.toString() ?? "00:00";
        final closes = getFirst(s['closes'])?.toString() ?? "00:00";
        if (opens == "00:00" && closes == "00:00") return {"isOpen": false, "message": "Closed for Holiday/Event"};
        final isOpen = timeStr.compareTo(opens) >= 0 && timeStr.compareTo(closes) <= 0;
        return {"isOpen": isOpen, "message": isOpen ? null : "Closed (Special Hours: $opens-$closes)"};
      }
    }

    // 2. Check Regular Opening Hours
    final regular = getArray(obj['openingHoursSpecification']);
    if (regular.isEmpty) return {"isOpen": true, "message": null};

    dynamic todayRegular;
    for (final r in regular) {
      if (r is! Map) continue;
      final days = getArray(r['dayOfWeek']).map((d) => d.toString().replaceAll('https://schema.org/', '')).toList();
      if (days.contains(todayName)) {
        todayRegular = r;
        break;
      }
    }

    if (todayRegular == null) return {"isOpen": false, "message": "Closed on $todayName"};

    final opens = getFirst(todayRegular['opens'])?.toString() ?? "00:00";
    final closes = getFirst(todayRegular['closes'])?.toString() ?? "23:59";
    final isOpen = timeStr.compareTo(opens) >= 0 && timeStr.compareTo(closes) <= 0;

    return {"isOpen": isOpen, "message": isOpen ? null : "Closed (Opens at $opens)"};
  }

  static String? extract3DModel(dynamic data) {
    final obj = data is List ? (data.isNotEmpty ? data[0] : null) : data;
    if (obj == null || obj is! Map) return null;

    final subjectOf = getArray(obj['subjectOf']);
    dynamic model;
    for (final s in subjectOf) {
      if (s is Map && getFirst(s['@type']) == "3DModel") {
        model = s;
        break;
      }
    }
    if (model == null) return null;

    final encoding = getFirst(model['encoding']);
    return encoding is Map ? getFirst(encoding['contentUrl'])?.toString() : null;
  }

  static int extractLeadTime(dynamic data) {
    final obj = data is List ? (data.isNotEmpty ? data[0] : null) : data;
    if (obj == null || obj is! Map) return 0;

    final itemOfferedFirst = getArray(obj['itemOffered']).isNotEmpty && getArray(obj['itemOffered'])[0] is Map ? getArray(obj['itemOffered'])[0] : null;
    final offersFirst = getArray(obj['offers']).isNotEmpty && getArray(obj['offers'])[0] is Map ? getArray(obj['offers'])[0] : null;

    final lt = getFirst(obj['deliveryLeadTime']) ??
        getFirst(itemOfferedFirst != null && itemOfferedFirst['offers'] is Map ? itemOfferedFirst['offers']['deliveryLeadTime'] : null) ??
        getFirst(itemOfferedFirst != null ? itemOfferedFirst['deliveryLeadTime'] : null) ??
        getFirst(offersFirst != null ? offersFirst['deliveryLeadTime'] : null) ??
        getFirst(offersFirst != null && offersFirst['itemOffered'] is Map ? offersFirst['itemOffered']['deliveryLeadTime'] : null);

    if (lt == null) return 0;

    if (lt is Map) {
      final val = int.tryParse(getFirst(lt['value'])?.toString() ?? '0') ?? 0;
      final unit = (getFirst(lt['unitCode']) ?? getFirst(lt['unitText']) ?? "MIN").toString();

      if (unit == 'HUR' || unit == 'hour' || unit == 'hours') return val * 60;
      if (unit == 'DAY' || unit == 'day' || unit == 'days') return val * 24 * 60;
      return val;
    }

    final str = lt.toString().toLowerCase();
    final numVal = int.tryParse(RegExp(r'\d+').firstMatch(str)?.group(0) ?? '0') ?? 0;
    if (str.contains('hour')) return numVal * 60;
    if (str.contains('day')) return numVal * 24 * 60;
    return numVal;
  }

  static bool isLocationInArea(double? targetLat, double? targetLon, dynamic targetAddress, dynamic area) {
    if (area == null) return true;

    final type = getFirst(area['@type'])?.toString();
    final name = normalizeName(getFirst(area['name'])?.toString() ?? "");
    final postalCode = getFirst(area['postalCode']);

    if (type == 'GeoCircle') {
      if (targetLat == null || targetLon == null) return false;
      final midpoint = area['geoMidpoint'];
      if (midpoint == null || midpoint is! Map) return false;
      final mLat = double.tryParse(getFirst(midpoint['latitude'])?.toString() ?? '0') ?? 0.0;
      final mLon = double.tryParse(getFirst(midpoint['longitude'])?.toString() ?? '0') ?? 0.0;
      final radius = double.tryParse(getFirst(area['geoRadius'])?.toString() ?? '0') ?? 0.0;

      final dist = _calculateDistance(targetLat, targetLon, mLat, mLon);
      return dist <= radius;
    }

    if (type == 'City' || type == 'AdministrativeArea' || type == 'State' || type == 'Country') {
      final tCity = normalizeName(targetAddress is Map ? targetAddress['addressLocality']?.toString() ?? "" : "");
      final tState = normalizeName(targetAddress is Map ? targetAddress['addressRegion']?.toString() ?? "" : "");
      final tCountry = normalizeName(targetAddress is Map ? targetAddress['addressCountry']?.toString() ?? "" : "");

      if (name == tCity || name == tState || name == tCountry) return true;
    }

    if (type == 'PostalAddress' || postalCode != null) {
      final tPin = targetAddress is Map ? targetAddress['postalCode']?.toString() ?? "" : "";
      final aPin = (postalCode ?? (area is Map ? getFirst(area['postalCode']) : null) ?? "").toString();
      if (tPin == aPin && tPin.isNotEmpty) return true;

      final tLoc = normalizeName(targetAddress is Map ? targetAddress['addressLocality']?.toString() ?? "" : "");
      final aLoc = normalizeName(area is Map ? getFirst(area['addressLocality'])?.toString() ?? "" : "");
      if (tLoc == aLoc && tLoc.isNotEmpty) return true;
    }

    return false;
  }

  static double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371e3;
    final p1 = lat1 * math.pi / 180;
    final p2 = lat2 * math.pi / 180;
    final dp = (lat2 - lat1) * math.pi / 180;
    final dl = (lon2 - lon1) * math.pi / 180;

    final a = math.sin(dp / 2) * math.sin(dp / 2) +
        math.cos(p1) * math.cos(p2) * math.sin(dl / 2) * math.sin(dl / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return r * c;
  }
}
