export class ProductionApiService {
  private static instance: ProductionApiService;
  private baseUrl: string = 'https://api.antinna.in';

  public static getInstance(): ProductionApiService {
    if (!ProductionApiService.instance) {
      ProductionApiService.instance = new ProductionApiService();
    }
    return ProductionApiService.instance;
  }

  private async request<T>(method: 'GET' | 'POST', path: string, body: any = null): Promise<T> {
    const headers: Record<string, string> = {
        'Content-Type': 'application/json',
        'X-Antinna-Client-Id': localStorage.getItem('antinna_client_id') || '',
        'Authorization': `Bearer ${(window as any).firebaseAuthToken || (window as any).firebaseAuth?.currentUser?.accessToken || ''}`
    };

    const options: RequestInit = { method, headers };
    if (body) options.body = JSON.stringify(body);

    try {
      const response = await fetch(`${this.baseUrl}${path}`, options);
      if (!response.ok) throw new Error(`API error! status: ${response.status}`);
      return await response.json();
    } catch (e) {
      console.error(`ProductionApiService error [${path}]:`, e);
      throw e;
    }
  }

  public async createOrder(order: any): Promise<any> {
    return this.request<any>('POST', '/orders', order);
  }

  public async recordPayment(paymentData: any): Promise<any> {
    return this.request<any>('POST', '/payments', paymentData);
  }

  public async isOrderPaid(orderId: string): Promise<any> {
    return this.request<any>('GET', `/orders/${orderId}/status`);
  }

  public async listNotifications(page: number = 1, pageSize: number = 20): Promise<any> {
    return this.request<any>('GET', `/notifications?page=${page}&pageSize=${pageSize}`);
  }
}
