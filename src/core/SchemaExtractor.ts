export class SchemaExtractor {
  static getFirst<T>(val: T | T[] | undefined): T | undefined {
    if (Array.isArray(val)) return val[0];
    return val;
  }

  static getArray<T>(val: T | T[] | undefined): T[] {
    if (val === undefined || val === null) return [];
    if (Array.isArray(val)) return val;
    return [val];
  }

  static decodeEntities(text: string): string {
    if (!text) return "";
    const textarea = document.createElement("textarea");
    textarea.innerHTML = text;
    let decoded = textarea.value;
    if (decoded.includes("&quot;")) {
        textarea.innerHTML = decoded;
        decoded = textarea.value;
    }
    return decoded;
  }

  static extractJsonLd<T>(input: string): T | null {
    if (!input) return null;

    try {
      const scriptMatch = input.match(/<script[^>]*type=["']application\/ld\+json["'][^>]*>([\s\S]*?)<\/script>/i);
      let jsonContent = scriptMatch ? scriptMatch[1] : input;

      let decoded = this.decodeEntities(jsonContent);

      const cleaned = decoded
        .replace(/\/\*[\s\S]*?\*\/|([^\\:]|^)\/\/.*$/gm, "$1")
        .trim();

      try {
        return JSON.parse(cleaned) as T;
      } catch (e) {
        const objectMatch = cleaned.match(/\{[\s\S]*\}/);
        if (objectMatch) {
          try { return JSON.parse(objectMatch[0]) as T; } catch(e2) {}
        }
        return null;
      }
    } catch (e) {
      console.error("Failed to extract JSON-LD", e);
      return null;
    }
  }

  static findMatchingVariant(parent: any, selectedAttributes: Record<string, string>, lastClickedAttr: string | null = null): any {
    if (!parent) return null;
    const variants = this.getArray(parent.hasVariant).length > 0 ? this.getArray(parent.hasVariant) : [parent];

    let match = variants.find((v: any) =>
      Object.entries(selectedAttributes).every(([k, val]) => String(this.getFirst(v[k])) === String(val))
    );

    if (!match && lastClickedAttr) {
      match = variants.find((v: any) => String(this.getFirst(v[lastClickedAttr])) === String(selectedAttributes[lastClickedAttr]));
    }

    return match || variants[0];
  }

  static normalizeName(name: string): string {
      return (name || '').toLowerCase().trim().replace(/\s+/g, ' ');
  }

  static findMatchingServicePackage(parent: any, packageName: string): any {
      const catalogs = this.getArray(parent?.hasOfferCatalog);
      if (catalogs.length === 0) return null;

      const normalizedSearch = this.normalizeName(packageName);

      for (const catalog of catalogs) {
          const elements = this.getArray(catalog.itemListElement);
          const found = elements.find((off: any) => {
              const item = off.itemOffered || off;
              const name = this.getFirst(item.name) || this.getFirst(off.name);
              return this.normalizeName(name as string) === normalizedSearch;
          });
          if (found) return found;
      }
      return null;
  }

  static findAllServices(obj: any): any[] {
      const results: any[] = [];
      const stack = [obj];
      const seen = new Set();

      while (stack.length > 0) {
          const current = stack.pop();
          if (!current || typeof current !== 'object' || seen.has(current)) continue;
          seen.add(current);

          // Find via OfferCatalog
          if (current.hasOfferCatalog) {
              const catalogs = this.getArray(current.hasOfferCatalog);
              catalogs.forEach(cat => {
                  const elements = this.getArray(cat.itemListElement);
                  results.push(...elements);
                  stack.push(cat);
              });
          }

          // Find via addOn
          if (current.addOn) {
              results.push(...this.getArray(current.addOn));
          }

          // Direct items in an array
          if (Array.isArray(current)) {
              stack.push(...current);
          } else {
              // Descend into other objects
              for (const [key, val] of Object.entries(current)) {
                  if (key !== 'hasOfferCatalog' && key !== 'addOn' && val && typeof val === 'object') {
                      stack.push(val);
                  }
              }
          }
      }
      return results;
  }

  static extractPrice(offer: any): { price: string, currency: string } {
      return this.extractPriceForQuantity(offer, 1);
  }

  static extractPriceForQuantity(offer: any, quantity: number): { price: string, currency: string } {
      const off = Array.isArray(offer) ? offer[0] : offer;
      if (!off) return { price: "0", currency: "INR" };

      // Check for priceSpecification
      const specs = this.getArray(off.priceSpecification ||
                                   this.getArray(off.itemOffered)[0]?.offers?.priceSpecification ||
                                   this.getArray(off.offers)[0]?.priceSpecification ||
                                   this.getArray(off.offers)[0]?.itemOffered?.offers?.priceSpecification);

      if (specs.length > 0) {
          const matchingSpec = specs.find((spec: any) => {
              if (this.getFirst(spec["@type"]) !== "UnitPriceSpecification") return false;
              const eq = this.getFirst(spec.eligibleQuantity);
              if (!eq) return true; // Default if no quantity specified on this spec

              const min = this.getFirst(eq.minValue);
              const max = this.getFirst(eq.maxValue);

              const minVal = (min !== undefined && min !== null) ? Number(min) : 0;
              const maxVal = (max !== undefined && max !== null) ? Number(max) : Infinity;

              return quantity >= minVal && quantity <= maxVal;
          });

          if (matchingSpec) {
              const price = this.getFirst(matchingSpec.price) || "0";
              const currency = this.getFirst(matchingSpec.priceCurrency) || "INR";
              return { price: String(price), currency: String(currency) };
          }
      }

      const price = this.getFirst(off.price) ||
                    this.getFirst(this.getArray(off.itemOffered)[0]?.offers?.price) ||
                    this.getFirst(this.getArray(off.offers)[0]?.price) || "0";

      const currency = this.getFirst(off.priceCurrency) ||
                       this.getFirst(this.getArray(off.itemOffered)[0]?.offers?.priceCurrency) ||
                       this.getFirst(this.getArray(off.offers)[0]?.priceCurrency) || "INR";

      return { price: String(price), currency: String(currency) };
  }

  static extractAvailability(offer: any): string {
      const off = Array.isArray(offer) ? offer[0] : offer;
      if (!off) return "https://schema.org/InStock";

      const av = this.getFirst(off.availability) ||
                 this.getFirst(this.getArray(off.itemOffered)[0]?.offers?.availability) ||
                 this.getFirst(this.getArray(off.offers)[0]?.availability) || "https://schema.org/InStock";

      // If availability is an object with @id, use that, otherwise stringify
      return (av as any)?.["@id"] || String(av);
  }

  static extractEligibleQuantity(data: any): { minValue: number | null, maxValue: number | null } {
      const obj = Array.isArray(data) ? data[0] : data;
      if (!obj) return { minValue: null, maxValue: null };

      const eq = this.getFirst(obj.eligibleQuantity) ||
                 this.getFirst(this.getArray(obj.itemOffered)[0]?.offers?.eligibleQuantity) ||
                 this.getFirst(this.getArray(obj.itemOffered)[0]?.eligibleQuantity) ||
                 this.getFirst(this.getArray(obj.offers)[0]?.eligibleQuantity) ||
                 this.getFirst(this.getArray(obj.offers)[0]?.itemOffered?.eligibleQuantity);

      if (!eq) return { minValue: null, maxValue: null };

      const min = this.getFirst(eq.minValue);
      const max = this.getFirst(eq.maxValue);

      return {
          minValue: (min !== undefined && min !== null) ? Number(min) : null,
          maxValue: (max !== undefined && max !== null) ? Number(max) : null
      };
  }

  static extractInventoryLevel(data: any): number | null {
      const obj = Array.isArray(data) ? data[0] : data;
      if (!obj) return null;

      const il = this.getFirst(obj.inventoryLevel) ||
                 this.getFirst(this.getArray(obj.itemOffered)[0]?.offers?.inventoryLevel) ||
                 this.getFirst(this.getArray(obj.itemOffered)[0]?.inventoryLevel) ||
                 this.getFirst(this.getArray(obj.offers)[0]?.inventoryLevel) ||
                 this.getFirst(this.getArray(obj.offers)[0]?.itemOffered?.inventoryLevel);

      if (!il) return null;

      const val = typeof il === 'object' ? this.getFirst(il.value) : il;
      return (val !== undefined && val !== null) ? Number(val) : null;
  }

  static extractDimensions(data: any): { weight: number | null, height: number | null, width: number | null, depth: number | null } {
      const obj = Array.isArray(data) ? data[0] : data;
      if (!obj) return { weight: null, height: null, width: null, depth: null };

      const getNum = (v: any) => {
          if (v === undefined || v === null) return null;
          if (typeof v === 'object') return Number(this.getFirst(v.value)) || null;
          return Number(v) || null;
      };

      return {
          weight: getNum(obj.weight),
          height: getNum(obj.height),
          width: getNum(obj.width),
          depth: getNum(obj.depth)
      };
  }

  static extractAdvanceBookingRequirement(offer: any): string | null {
      const off = Array.isArray(offer) ? offer[0] : offer;
      if (!off) return null;

      const abr = this.getFirst(off.advanceBookingRequirement);
      if (!abr) return null;

      if (typeof abr === 'string') return abr;

      const val = this.getFirst(abr.value);
      const unit = this.getFirst(abr.unitCode) || this.getFirst(abr.unitText) || "";

      if (val === undefined) return null;

      let unitLabel = unit;
      if (unit === 'HUR') unitLabel = 'Hours';
      else if (unit === 'DAY') unitLabel = 'Days';

      return `${val} ${unitLabel}`.trim();
  }

  static getCurrencySymbol(currency: string): string {
      const symbols: Record<string, string> = {
          'INR': '₹',
          'USD': '$',
          'EUR': '€',
          'GBP': '£',
          'JPY': '¥'
      };
      return symbols[currency.toUpperCase()] || currency;
  }

  static extractCondition(data: any): string | null {
      const obj = Array.isArray(data) ? data[0] : data;
      if (!obj) return null;

      const cond = this.getFirst(obj.itemCondition) ||
                   this.getFirst(this.getArray(obj.itemOffered)[0]?.offers?.itemCondition) ||
                   this.getFirst(this.getArray(obj.itemOffered)[0]?.itemCondition) ||
                   this.getFirst(this.getArray(obj.offers)[0]?.itemCondition) ||
                   this.getFirst(this.getArray(obj.offers)[0]?.itemOffered?.itemCondition);

      if (!cond) return null;

      const str = String(cond).toLowerCase();
      if (str.includes("newcondition")) return "New";
      if (str.includes("refurbishedcondition")) return "Refurbished";
      if (str.includes("usedcondition")) return "Used";
      if (str.includes("damagedcondition")) return "Damaged";

      return str.split('/').pop() || str;
  }

  static extractAreaServed(data: any): any[] {
      const results: any[] = [];
      const stack = [data];
      const seen = new Set();

      while (stack.length > 0) {
          const current = stack.pop();
          if (!current || typeof current !== 'object' || seen.has(current)) continue;
          seen.add(current);

          const areas = this.getArray(current.areaServed || current.eligibleRegion);
          if (areas.length > 0) {
              results.push(...areas);
          }

          // Descend into common Schema.org containers
          if (current.itemOffered) stack.push(current.itemOffered);
          if (current.offers) stack.push(...this.getArray(current.offers));
          if (current.hasVariant) stack.push(...this.getArray(current.hasVariant));
          if (current.hasOfferCatalog) stack.push(...this.getArray(current.hasOfferCatalog));
          if (current.itemListElement) stack.push(...this.getArray(current.itemListElement));
      }

      return results;
  }

  static isBusinessOpen(data: any): { isOpen: boolean, message: string | null } {
      const obj = Array.isArray(data) ? data[0] : data;
      if (!obj) return { isOpen: true, message: null };

      const now = new Date();
      const todayStr = now.toISOString().split('T')[0];
      const timeStr = now.getHours().toString().padStart(2, '0') + ":" + now.getMinutes().toString().padStart(2, '0');
      const dayNames = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"];
      const todayName = dayNames[now.getDay()];

      // 1. Check Special Opening Hours (Overrides)
      const special = this.getArray(obj.specialOpeningHoursSpecification);
      for (const s of special) {
          const from = this.getFirst(s.validFrom);
          const through = this.getFirst(s.validThrough);
          if (from && through && todayStr >= String(from) && todayStr <= String(through)) {
              const opens = String(this.getFirst(s.opens) || "00:00");
              const closes = String(this.getFirst(s.closes) || "00:00");
              if (opens === "00:00" && closes === "00:00") return { isOpen: false, message: "Closed for Holiday/Event" };
              const isOpen = timeStr >= opens && timeStr <= closes;
              return { isOpen, message: isOpen ? null : `Closed (Special Hours: ${opens}-${closes})` };
          }
      }

      // 2. Check Regular Opening Hours
      const regular = this.getArray(obj.openingHoursSpecification);
      if (regular.length === 0) return { isOpen: true, message: null }; // No hours defined, assume open

      const todayRegular = regular.find(r => {
          const days = this.getArray(r.dayOfWeek).map(d => String(d).replace('https://schema.org/', ''));
          return days.includes(todayName);
      });

      if (!todayRegular) return { isOpen: false, message: `Closed on ${todayName}` };

      const opens = String(this.getFirst(todayRegular.opens) || "00:00");
      const closes = String(this.getFirst(todayRegular.closes) || "23:59");
      const isOpen = timeStr >= opens && timeStr <= closes;

      return { isOpen, message: isOpen ? null : `Closed (Opens at ${opens})` };
  }

  static extract3DModel(data: any): string | null {
      const obj = Array.isArray(data) ? data[0] : data;
      if (!obj) return null;

      const subjectOf = this.getArray(obj.subjectOf);
      const model = subjectOf.find(s => this.getFirst(s["@type"]) === "3DModel");
      if (!model) return null;

      const encoding = this.getFirst(model.encoding);
      return this.getFirst(encoding?.contentUrl) || null;
  }

  static extractLeadTime(data: any): number {
      const obj = Array.isArray(data) ? data[0] : data;
      if (!obj) return 0;

      const lt = this.getFirst(obj.deliveryLeadTime) ||
                 this.getFirst(this.getArray(obj.itemOffered)[0]?.offers?.deliveryLeadTime) ||
                 this.getFirst(this.getArray(obj.itemOffered)[0]?.deliveryLeadTime) ||
                 this.getFirst(this.getArray(obj.offers)[0]?.deliveryLeadTime) ||
                 this.getFirst(this.getArray(obj.offers)[0]?.itemOffered?.deliveryLeadTime);

      if (!lt) return 0;

      // Handle QuantitativeValue
      if (typeof lt === 'object') {
          const val = Number(this.getFirst(lt.value)) || 0;
          const unit = this.getFirst(lt.unitCode) || this.getFirst(lt.unitText) || "MIN";

          if (unit === 'HUR' || unit === 'hour' || unit === 'hours') return val * 60;
          if (unit === 'DAY' || unit === 'day' || unit === 'days') return val * 24 * 60;
          return val; // Assume minutes by default
      }

      // Handle string "35 mins" or "1 hour"
      const str = String(lt).toLowerCase();
      const num = parseInt(str) || 0;
      if (str.includes('hour')) return num * 60;
      if (str.includes('day')) return num * 24 * 60;
      return num;
  }

  static isLocationInArea(targetLat: number | null, targetLon: number | null, targetAddress: any, area: any): boolean {
      if (!area) return true; // If no area defined, assume global

      const type = this.getFirst(area["@type"]);
      const name = this.normalizeName(this.getFirst(area.name) || "");
      const postalCode = this.getFirst(area.postalCode);

      // 1. Check GeoCircle / GeoShape
      if (type === 'GeoCircle') {
          if (targetLat === null || targetLon === null) return false;
          const midpoint = area.geoMidpoint;
          if (!midpoint) return false;
          const mLat = Number(this.getFirst(midpoint.latitude));
          const mLon = Number(this.getFirst(midpoint.longitude));
          const radius = Number(this.getFirst(area.geoRadius)) || 0; // in meters

          const dist = this.calculateDistance(targetLat, targetLon, mLat, mLon);
          return dist <= radius;
      }

      // 2. Check City / State / AdministrativeArea
      if (type === 'City' || type === 'AdministrativeArea' || type === 'State' || type === 'Country') {
          const tCity = this.normalizeName(targetAddress?.addressLocality || "");
          const tState = this.normalizeName(targetAddress?.addressRegion || "");
          const tCountry = this.normalizeName(targetAddress?.addressCountry || "");

          if (name === tCity || name === tState || name === tCountry) return true;
      }

      // 3. Check PostalAddress / PostalCode
      if (type === 'PostalAddress' || postalCode) {
          const tPin = String(targetAddress?.postalCode || "");
          const aPin = String(postalCode || this.getFirst(area.postalCode) || "");
          if (tPin === aPin && tPin !== "") return true;

          // Also check locality in address
          const tLoc = this.normalizeName(targetAddress?.addressLocality || "");
          const aLoc = this.normalizeName(this.getFirst(area.addressLocality) || "");
          if (tLoc === aLoc && tLoc !== "") return true;
      }

      return false;
  }

  private static calculateDistance(lat1: number, lon1: number, lat2: number, lon2: number): number {
    const R = 6371e3; // metres
    const φ1 = lat1 * Math.PI/180;
    const φ2 = lat2 * Math.PI/180;
    const Δφ = (lat2-lat1) * Math.PI/180;
    const Δλ = (lon2-lon1) * Math.PI/180;

    const a = Math.sin(Δφ/2) * Math.sin(Δφ/2) +
              Math.cos(φ1) * Math.cos(φ2) *
              Math.sin(Δλ/2) * Math.sin(Δλ/2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));

    return R * c; // in metres
  }
}
