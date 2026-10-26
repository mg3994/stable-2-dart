export class AppsScriptService {
  private static instance: AppsScriptService;

  // Specific endpoint for Map/Geo services via Apps Script
  private mapUrl: string = 'https://script.google.com/macros/s/AKfycbyca4Xz_AE6Om1okIMf0TQ9EE9uIifQcVZhsDwnZK0K4weG7VD0w3jEzM0aCcuBeoWIIA/exec';

  public static getInstance(): AppsScriptService {
    if (!AppsScriptService.instance) {
      AppsScriptService.instance = new AppsScriptService();
    }
    return AppsScriptService.instance;
  }

  public setMapUrl(url: string): void {
    this.mapUrl = url;
  }

  private async callAction<T>(action: string, params: any = {}): Promise<T> {
    const payload = { action, params };

    try {
      // Use text/plain for GAS to avoid CORS preflight (OPTIONS) which GAS doesn't support
      const response = await fetch(this.mapUrl, {
          method: 'POST',
          headers: { 'Content-Type': 'text/plain;charset=utf-8' },
          body: JSON.stringify(payload)
      });

      if (!response.ok) throw new Error(`HTTP error! status: ${response.status}`);
      return await response.json();

    } catch (e) {
      console.error(`AppsScriptService error [${action}]:`, e);
      throw e;
    }
  }

  public async getPlaceSuggestions(inputToken: string): Promise<string[]> {
    try {
        const res = await this.callAction<any>('getPlaceSuggestions', { inputToken });
        return res.success ? res.suggestions : [];
    } catch (e) {
        return [];
    }
  }

  public async processLocationAndMetrics(originLat: number, originLng: number, destinationQuery: string): Promise<any> {
    return this.callAction<any>('processLocationAndMetrics', { originLat, originLng, destinationQuery });
  }

  public async processPinDropMetrics(originLat: number, originLng: number, pinLat: number, pinLng: number): Promise<any> {
    return this.callAction<any>('processPinDropMetrics', { originLat, originLng, pinLat, pinLng });
  }
}
