/**
 * ORDERS Project
 * Handles Order Creation and notifications.
 */

function doPost(e) {
  var payload;
  try {
    payload = parseRequestPayload(e);
  } catch (err) {
    return jsonError(err.toString());
  }

  if (payload.action === 'createOrder') {
    return handleCreateOrder(payload);
  }
  return jsonError("Unknown action");
}

function handleCreateOrder(payload) {
  var order = payload.order;
  var authToken = payload.authToken;

  try {
    // 1. Validate Token
    var auth = verifyFirebaseToken(authToken);
    // if (!auth.isValid) return jsonError("Invalid credentials");

    // 2. Generate ID and process
    var orderId = generateUniqueId("ANT");
    console.log("Order Created:", orderId, JSON.stringify(order));

    // 3. Optional: Send Notification to Merchant or User
    // if (payload.deviceToken) {
    //   sendFcmMessage(payload.deviceToken, "Order Confirmed!", "Your order " + orderId + " is being processed.");
    // }

    return jsonSuccess({
      orderId: orderId,
      message: "Order recorded successfully."
    });
  } catch (e) {
    return jsonError(e.toString());
  }
}
