import { Order, Product, Service, Organization } from '../types/schema';
import { SchemaExtractor } from './SchemaExtractor';

export class CartManager {
  private order: Order & { totalPrice?: number; priceCurrency?: string };
  private storageKey = "antinna_cart_order";

  constructor() {
    this.order = this.loadFromStorage() || {
      "@type": "Order",
      orderedItem: [],
      totalPrice: 0,
      priceCurrency: "INR",
    } as any;
    this.deduplicate();
  }

  private loadFromStorage(): Order | null {
    const data = localStorage.getItem(this.storageKey);
    if (!data) return null;
    try {
      return JSON.parse(data);
    } catch {
      return null;
    }
  }

  private saveToStorage(): void {
    this.calculateTotal();
    localStorage.setItem(this.storageKey, JSON.stringify(this.order));
  }

  private deduplicate(): void {
      const uniqueItems: Record<string, any> = {};
      const newOrderedItems: any[] = [];
      const orderedItems = SchemaExtractor.getArray(this.order.orderedItem);

      orderedItems.forEach((item: any) => {
          const key = item.itemKey || this.generateItemKey(item.orderedItem, item._selectedVariants);
          if (uniqueItems[key]) {
              uniqueItems[key].orderQuantity += item.orderQuantity;
          } else {
              item.itemKey = key;
              uniqueItems[key] = item;
              newOrderedItems.push(item);
          }
      });

      this.order.orderedItem = newOrderedItems;
      this.calculateTotal();
  }

  private calculateTotal(): void {
    const orderedItems = SchemaExtractor.getArray(this.order.orderedItem);
    this.order.totalPrice = orderedItems.reduce((sum: number, item: any) => {
      if (!this.isItemOrderable(item)) return sum;
      const qty = item.orderQuantity || 1;
      const { price } = SchemaExtractor.extractPriceForQuantity(item.orderedItem.offers, qty);
      let itemTotal = parseFloat(price) * qty;

      // Add price of addons
      const addOns = SchemaExtractor.getArray(item.addOns);
      addOns.forEach((addon: any) => {
        const addonQty = addon.orderQuantity || 0;
        const { price: addonPrice } = SchemaExtractor.extractPriceForQuantity(addon.orderedItem.offers, addonQty);
        itemTotal += parseFloat(addonPrice) * addonQty;
      });

      return sum + itemTotal;
    }, 0);
  }

  public isItemOrderable(item: any): boolean {
      if (item.isUnavailable) return false;
      const av = SchemaExtractor.extractAvailability(item.orderedItem?.offers);
      if (av === "https://schema.org/OutOfStock" || av === "https://schema.org/SoldOut") return false;
      return true;
  }

  public isItemQuantityValid(item: any): boolean {
      const min = item._constraints?.minValue;
      if (min !== null && min !== undefined && (item.orderQuantity || 1) < min) return false;
      return true;
  }

  public isCartValid(): boolean {
      const items = SchemaExtractor.getArray(this.order.orderedItem);
      if (items.length === 0) return false;
      return items.every(item => this.isItemOrderable(item) && this.isItemQuantityValid(item));
  }

  addItem(item: Product | Service, seller?: Organization, selectedVariants?: Record<string, string>, quantity: number = 1): string | null {
    const availability = SchemaExtractor.extractAvailability(item.offers);
    if (availability === "https://schema.org/OutOfStock") {
        return null;
    }

    if (!SchemaExtractor.getFirst(item.url)) {
        item.url = window.location.href.split('?')[0].split('#')[0];
    }

    const itemKey = this.generateItemKey(item, selectedVariants);
    const orderedItems = SchemaExtractor.getArray(this.order.orderedItem);

    const existing = orderedItems.find(
      (oi: any) => oi.itemKey === itemKey
    );

    const { minValue, maxValue } = SchemaExtractor.extractEligibleQuantity(item);
    const inventoryLevel = SchemaExtractor.extractInventoryLevel(item.offers || item);
    const effectiveMax = (maxValue !== null && inventoryLevel !== null) ? Math.min(maxValue, inventoryLevel) : (maxValue || inventoryLevel);

    const initialQty = Math.max(Number(quantity), minValue || 1);

    if (existing) {
      const currentQty = Number((existing as any).orderQuantity || 0);
      const newQty = currentQty + Number(quantity);

      if (effectiveMax !== null && newQty > effectiveMax) {
          const UIManager = (window as any).UIManager;
          if (UIManager) UIManager.showToast(`Maximum limit of ${effectiveMax} reached for this item`, "error");
          (existing as any).orderQuantity = effectiveMax;
      } else {
          (existing as any).orderQuantity = newQty;
      }
      this.saveToStorage();
      return itemKey;
    } else {
      const itemCopy = JSON.parse(JSON.stringify(item));

      // Ensure quantity doesn't exceed max on first add
      const finalInitialQty = effectiveMax !== null ? Math.min(initialQty, effectiveMax) : initialQty;

      orderedItems.push({
        "@type": "OrderItem",
        orderedItem: {
          ...itemCopy,
          url: item.url,
          _selectedVariants: selectedVariants ? { ...selectedVariants } : undefined
        },
        orderQuantity: finalInitialQty,
        seller: seller ? JSON.parse(JSON.stringify(seller)) : undefined,
        itemKey: itemKey,
        _constraints: { minValue, maxValue, inventoryLevel },
        addOns: []
      } as any);
      this.order.orderedItem = orderedItems;
      this.saveToStorage();
      return itemKey;
    }
  }

  addAddOn(parentItemKey: string, addon: Product | Service, quantity: number = 1): void {
    const orderedItems = SchemaExtractor.getArray(this.order.orderedItem);
    const parent = orderedItems.find((oi: any) => oi.itemKey === parentItemKey);

    if (!parent) {
      const UIManager = (window as any).UIManager;
      if (UIManager) UIManager.showToast("Please add the main product first", "error");
      return;
    }

    if (!parent.addOns) parent.addOns = [];

    const addonKey = this.generateItemKey(addon);
    const existing = parent.addOns.find((a: any) => a.itemKey === addonKey);

    if (existing) {
      const limits = this.getAddOnLimits(parent, existing);
      const newQty = (existing.orderQuantity || 0) + quantity;
      if (limits.maxValue !== null && newQty > limits.maxValue) {
        existing.orderQuantity = limits.maxValue;
      } else {
        existing.orderQuantity = newQty;
      }
    } else {
      const { minValue, maxValue } = SchemaExtractor.extractEligibleQuantity(addon);
      const inventoryLevel = SchemaExtractor.extractInventoryLevel(addon.offers || addon);
      const tempAddon = {
        orderedItem: JSON.parse(JSON.stringify(addon)),
        _constraints: { minValue, maxValue, inventoryLevel }
      };
      const dynamicLimits = this.getAddOnLimits(parent, tempAddon);

      parent.addOns.push({
        orderedItem: tempAddon.orderedItem,
        orderQuantity: Math.max(quantity, dynamicLimits.minValue || 1),
        itemKey: addonKey,
        _constraints: { minValue, maxValue, inventoryLevel }
      });
    }
    this.saveToStorage();
  }

  public getAddOnLimits(parent: any, addon: any): { minValue: number | null, maxValue: number | null } {
    const parentQty = parent.orderQuantity || 1;
    const min = addon._constraints?.minValue;
    const max = addon._constraints?.maxValue;
    const inventoryLevel = addon._constraints?.inventoryLevel;

    const scaledMax = (max !== undefined && max !== null) ? max * parentQty : null;

    // Inventory level is global, not per-parent-unit.
    // However, if the user bought 2 base products, and max gift wraps per product is 3, but inventory is 5,
    // then effective max is 5.
    const effectiveMax = (scaledMax !== null && inventoryLevel !== null) ? Math.min(scaledMax, inventoryLevel) : (scaledMax || inventoryLevel);

    return {
      minValue: (min !== undefined && min !== null) ? min * parentQty : null,
      maxValue: effectiveMax
    };
  }

  public generateItemKey(item: Product | Service | any, variants?: Record<string, string>): string {
    let url = SchemaExtractor.getFirst(item.url) || '';
    if (url.includes('?')) url = url.split('?')[0];
    if (url.includes('#')) url = url.split('#')[0];
    url = url.toLowerCase().replace(/\/$/, "");

    const type = SchemaExtractor.getFirst(item["@type"]) || "Product";
    const name = SchemaExtractor.getFirst(item.name) || '';
    const sku = SchemaExtractor.getFirst(item.sku) || '';

    let variantString = '';
    if (variants) {
      const sortedKeys = Object.keys(variants).sort();
      variantString = sortedKeys.map(k => `${k}:${variants[k]}`).join('|');
    }

    return `${url}::${type}::${sku}::${name}::${variantString}`;
  }

  removeItem(index: number): void {
    const orderedItems = SchemaExtractor.getArray(this.order.orderedItem);
    if (index < 0 || index >= orderedItems.length) return;
    orderedItems.splice(index, 1);
    this.order.orderedItem = orderedItems;
    this.saveToStorage();
  }

  updateQty(index: number, delta: number): void {
    const orderedItems = SchemaExtractor.getArray(this.order.orderedItem);
    const item = orderedItems[index] as any;
    if (!item) return;

    const oldQty = item.orderQuantity || 0;
    const newQty = oldQty + delta;
    const { maxValue, inventoryLevel } = item._constraints || {};
    const effectiveMax = (maxValue !== null && inventoryLevel !== null) ? Math.min(maxValue, inventoryLevel) : (maxValue || inventoryLevel);

    if (delta > 0 && effectiveMax !== null && effectiveMax !== undefined && newQty > effectiveMax) {
        const UIManager = (window as any).UIManager;
      if (UIManager) UIManager.showToast(`Maximum limit of ${effectiveMax} reached`, "error");
        return;
    }

    item.orderQuantity = newQty;

    // Proportional scaling of addons when parent quantity changes
    if (item.addOns) {
      const oldParentQty = oldQty || 1;
      const newParentQty = newQty;

      item.addOns.forEach((addon: any) => {
        // Calculate ratio of current addon qty to old parent qty
        const ratio = (addon.orderQuantity || 0) / oldParentQty;
        // New qty should maintain the same ratio
        addon.orderQuantity = Math.round(ratio * newParentQty);

        // Enforce dynamic limits based on new parent quantity
        const limits = this.getAddOnLimits(item, addon);
        if (limits.maxValue !== null && addon.orderQuantity > limits.maxValue) {
          addon.orderQuantity = limits.maxValue;
        }
        if (limits.minValue !== null && addon.orderQuantity < limits.minValue) {
          addon.orderQuantity = limits.minValue;
        }
      });
    }

    if (item.orderQuantity <= 0) {
      this.removeItem(index);
    } else {
      this.saveToStorage();
    }
  }

  updateAddOnQty(parentIndex: number, addonIndex: number, delta: number): void {
    const orderedItems = SchemaExtractor.getArray(this.order.orderedItem);
    const parent = orderedItems[parentIndex] as any;
    if (!parent || !parent.addOns) return;

    const addon = parent.addOns[addonIndex];
    if (!addon) return;

    const newQty = (addon.orderQuantity || 0) + delta;
    const limits = this.getAddOnLimits(parent, addon);

    if (delta > 0 && limits.maxValue !== null && newQty > limits.maxValue) {
      const UIManager = (window as any).UIManager;
      if (UIManager) UIManager.showToast(`Maximum limit of ${limits.maxValue} reached`, "error");
      return;
    }

    if (delta < 0 && limits.minValue !== null && newQty < limits.minValue) {
      const UIManager = (window as any).UIManager;
      if (UIManager) UIManager.showToast(`Minimum of ${limits.minValue} required`, "error");
      return;
    }

    addon.orderQuantity = newQty;
    if (addon.orderQuantity <= 0) {
      parent.addOns.splice(addonIndex, 1);
    }
    this.saveToStorage();
  }

  removeAddOn(parentIndex: number, addonIndex: number): void {
      const orderedItems = SchemaExtractor.getArray(this.order.orderedItem);
      const parent = orderedItems[parentIndex] as any;
      if (!parent || !parent.addOns) return;

      parent.addOns.splice(addonIndex, 1);
      this.saveToStorage();
  }

  updateItemDetails(index: number, freshBaseData: any | null): void {
    const orderedItems = SchemaExtractor.getArray(this.order.orderedItem);
    const item = orderedItems[index] as any;
    if (!item) return;

    if (!freshBaseData) {
      item.isUnavailable = true;
    } else {
      let freshMatch = null;
      const cartItem = item.orderedItem;
      const dataSources = Array.isArray(freshBaseData) ? freshBaseData : [freshBaseData];

      const normalizedCartName = SchemaExtractor.normalizeName(cartItem.name);

      for (const source of dataSources) {
          const allServices = SchemaExtractor.findAllServices(source);
          for (const serviceOffer of allServices) {
              const item = serviceOffer.itemOffered || serviceOffer;
              const name = SchemaExtractor.getFirst(item.name) || SchemaExtractor.getFirst(serviceOffer.name);
              if (SchemaExtractor.normalizeName(name as string) === normalizedCartName) {
                  freshMatch = serviceOffer;
                  break;
              }
          }
          if (freshMatch) break;

          if (cartItem["@type"] === "Product" && source.hasVariant) {
              const variantMatch = SchemaExtractor.findMatchingVariant(source, cartItem._selectedVariants || {});
              if (variantMatch) {
                  freshMatch = variantMatch;
                  break;
              }
          }

          const sourceId = SchemaExtractor.getFirst(source.sku) || SchemaExtractor.getFirst(source.identifier) || SchemaExtractor.getFirst(source.name);
          const cartId = SchemaExtractor.getFirst(cartItem.sku) || SchemaExtractor.getFirst(cartItem.identifier) || SchemaExtractor.getFirst(cartItem.name);
          if (SchemaExtractor.getFirst(source["@type"]) === SchemaExtractor.getFirst(cartItem["@type"]) && sourceId === cartId) {
              freshMatch = source;
              break;
          }
      }

      if (freshMatch) {
          item.isUnavailable = false;
          const { price, currency } = SchemaExtractor.extractPrice(freshMatch);
          const availability = SchemaExtractor.extractAvailability(freshMatch);
          const { minValue, maxValue } = SchemaExtractor.extractEligibleQuantity(freshMatch);
          const inventoryLevel = SchemaExtractor.extractInventoryLevel(freshMatch.offers || freshMatch);

          item._constraints = { minValue, maxValue, inventoryLevel };
          item.orderedItem.offers = {
              "@type": "Offer",
              price: price,
              priceCurrency: currency,
              availability: availability,
              priceSpecification: freshMatch.priceSpecification || freshMatch.offers?.priceSpecification,
              eligibleQuantity: (minValue !== null || maxValue !== null) ? {
                  "@type": "QuantitativeValue",
                  minValue,
                  maxValue
              } : undefined
          };

          const matchedItem = freshMatch.itemOffered || freshMatch;
          item.orderedItem.image = matchedItem.image || item.orderedItem.image;
          item.orderedItem.name = matchedItem.name || item.orderedItem.name;
          item.orderedItem.description = matchedItem.description || item.orderedItem.description;

          // Update AddOns
          if (item.addOns) {
              item.addOns.forEach((addon: any) => {
                  let addonMatch = null;
                  const normalizedAddonName = SchemaExtractor.normalizeName(addon.orderedItem.name);

                  for (const source of dataSources) {
                      const allServices = SchemaExtractor.findAllServices(source);
                      for (const serviceOffer of allServices) {
                          const sItem = serviceOffer.itemOffered || serviceOffer;
                          const sName = SchemaExtractor.getFirst(sItem.name) || SchemaExtractor.getFirst(serviceOffer.name);
                          if (SchemaExtractor.normalizeName(sName as string) === normalizedAddonName) {
                              addonMatch = serviceOffer;
                              break;
                          }
                      }
                      if (addonMatch) break;
                  }

                  if (addonMatch) {
                      const { price: aPrice, currency: aCurrency } = SchemaExtractor.extractPrice(addonMatch);
                      const aAvailability = SchemaExtractor.extractAvailability(addonMatch);
                      const { minValue: aMin, maxValue: aMax } = SchemaExtractor.extractEligibleQuantity(addonMatch);
                      const aInv = SchemaExtractor.extractInventoryLevel(addonMatch.offers || addonMatch);

                      addon._constraints = { minValue: aMin, maxValue: aMax, inventoryLevel: aInv };
                      addon.orderedItem.offers = {
                          "@type": "Offer",
                          price: aPrice,
                          priceCurrency: aCurrency,
                          availability: aAvailability,
                          priceSpecification: addonMatch.priceSpecification || addonMatch.offers?.priceSpecification,
                          eligibleQuantity: (aMin !== null || aMax !== null) ? {
                              "@type": "QuantitativeValue",
                              minValue: aMin,
                              maxValue: aMax
                          } : undefined,
                          inventoryLevel: aInv !== null ? {
                              "@type": "QuantitativeValue",
                              value: aInv
                          } : undefined
                      };
                  }
              });
          }
      } else {
          item.isUnavailable = true;
      }
    }
    this.saveToStorage();
  }

  getOrder(): Order {
    return this.order;
  }

  getTotalQuantity(): number {
    const orderedItems = SchemaExtractor.getArray(this.order.orderedItem);
    return orderedItems.reduce((sum: number, item: any) => sum + Number(item.orderQuantity || 0), 0);
  }

  getServiceabilityErrors(verifiedLocation: any): string[] {
      const items = SchemaExtractor.getArray(this.order.orderedItem);
      const errors: string[] = [];

      items.forEach((item: any) => {
          const itemOffered = item.orderedItem;
          const areas = SchemaExtractor.extractAreaServed(itemOffered);

          if (areas.length > 0) {
              const isServiceable = areas.some(area =>
                  SchemaExtractor.isLocationInArea(verifiedLocation?.lat, verifiedLocation?.lon || verifiedLocation?.lng, verifiedLocation?.addressDetails, area)
              );
              if (!isServiceable) {
                  errors.push(SchemaExtractor.getFirst(itemOffered.name) || "An item");
              }
          }

          // Check Business Hours
          const seller = item.seller;
          if (seller) {
              const status = SchemaExtractor.isBusinessOpen(seller);
              if (!status.isOpen) {
                  errors.push(`${SchemaExtractor.getFirst(itemOffered.name)} (Seller currently closed: ${status.message})`);
              }
          }

          // Check addons
          if (item.addOns) {
              item.addOns.forEach((addon: any) => {
                  const aAreas = SchemaExtractor.extractAreaServed(addon.orderedItem);
                  if (aAreas.length > 0) {
                      const isAServiceable = aAreas.some(area =>
                          SchemaExtractor.isLocationInArea(verifiedLocation?.lat, verifiedLocation?.lon || verifiedLocation?.lng, verifiedLocation?.addressDetails, area)
                      );
                      if (!isAServiceable) {
                          errors.push(SchemaExtractor.getFirst(addon.orderedItem.name) || "An addon");
                      }
                  }
              });
          }
      });

      return errors;
  }

  getMaxLeadTime(): number {
      const items = SchemaExtractor.getArray(this.order.orderedItem);
      let maxLead = 0;

      items.forEach((item: any) => {
          const lead = SchemaExtractor.extractLeadTime(item.orderedItem);
          if (lead > maxLead) maxLead = lead;

          if (item.addOns) {
              item.addOns.forEach((addon: any) => {
                  const aLead = SchemaExtractor.extractLeadTime(addon.orderedItem);
                  if (aLead > maxLead) maxLead = aLead;
              });
          }
      });

      return maxLead;
  }

  clear(): void {
    this.order.orderedItem = [];
    this.saveToStorage();
  }
}
