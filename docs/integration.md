# Antinna Engine Integration Guide

This guide explains how to integrate the compiled Antinna Engine into your Blogger XML template.

## Option 1: Inline Script (IIFE) - Recommended for Blogger

This method is the most compatible with Blogger's XML structure and works best with inline `onclick` handlers.

### Step 1: Build the Project
Run the following command to generate the production bundle:
```bash
npm run build
```

### Step 2: Copy the Code
Open `dist/antinna-engine.iife.js` and copy its entire content.

### Step 3: Paste into Blogger XML
In your Blogger Dashboard, go to **Theme > Edit HTML**. Find the closing `</body>` tag and paste the code inside a `<script>` tag:

```xml
<!-- Antinna Engine IIFE -->
<script type='text/javascript'>
//<![CDATA[
  // PASTE THE CONTENT OF dist/antinna-engine.iife.js HERE
//]]>
</script>
```

**Pros:**
- Works immediately on page load.
- Managers like `CartManager` and `LocationManager` are globally accessible.
- Best for legacy XML `onclick="CartManager.addItem(...)"` calls.

---

## Option 2: ES Module (ESM)

Use this method if you want to use modern JavaScript features and keep the global scope clean, or if you are hosting the script on a CDN.

### Step 1: Host the File
Upload `dist/antinna-engine.es.js` to a reliable host or CDN (e.g., GitHub Pages, Netlify).

### Step 2: Integrate in Blogger XML
Paste the following code before the closing `</body>` tag:

```xml
<!-- Antinna Engine ESM -->
<script type='module'>
//<![CDATA[
  import '/path/to/your/antinna-engine.es.js';
//]]>
</script>
```

**Note:** When using `type='module'`, the classes are not automatically global. However, the Antinna Engine is designed to attach its managers to `window` automatically during initialization to maintain compatibility.

---

## Google Pay Configuration

To update your Google Pay Merchant details, edit `src/infrastructure/GooglePayService.ts` before building:

```typescript
private merchantId = "BCR2DN5TVPLKL4KZ"; // Your Merchant ID
private merchantName = "Antinna";         // Your Business Name
// In initPayment():
pa: 'your-vpa@upi',                    // Your UPI ID (VPA)
```

## Schema.org Usage in Posts

The engine extracts data from your Blogger posts. Ensure your post content follows either of these formats:

### Format A: Script Tag (Standard)
```html
<script type="application/ld+json">
{
  "@context": "https://schema.org",
  "@type": "Product",
  "name": "My Awesome Product",
  ...
}
</script>
```

### Format B: Raw JSON (Clean)
Simply paste the JSON object directly into the post body (HTML mode):
```json
{
  "@context": "https://schema.org",
  "@type": "Service",
  "name": "Expert Consulting",
  ...
}
```
