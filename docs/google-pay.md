# Google Pay Integration

The engine implements Google Pay for India (Tez) using the browser's native **Payment Request API**.

## Configuration

The payment details are defined in `src/infrastructure/GooglePayService.ts`.

### Credentials:
- **Merchant ID**: `BCR2DN5TVPLKL4KZ`
- **Merchant Name**: `Antinna`
- **VPA (UPI ID)**: `manishsharma3994@okhdfcbank`
- **MCC (Merchant Category Code)**: `5251` (Hardware Stores)

## How it Works

1.  **Preparation**: When the user clicks "Confirm Order" in the cart, the `GooglePayService.initPayment()` method is called with the current `Order` object.
2.  **Instrumentation**: The engine constructs a `PaymentRequest` targeting the `https://tez.google.com/pay` method.
3.  **UI Launch**: If the browser supports the API and the user is ready to pay, the native Google Pay UI appears on their mobile device or desktop.
4.  **Currency**: All transactions are processed in `INR` (Indian Rupee) as required by the NPCI UPI linking specifications.

## Brand Guidelines
We follow the [Google Pay Brand Guidelines](https://developers.google.com/pay/india/api/web/brand-guidelines) to ensure trust and consistency for your customers.
