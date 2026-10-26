/**
 * NOTIFICATIONS Project
 * Dedicated project for sending Push Notifications via FCM.
 */

function doPost(e) {
  var payload;
  try {
    payload = parseRequestPayload(e);
  } catch (err) {
    return jsonError(err.toString());
  }

  var action = payload.action;
  switch (action) {
    case 'sendNotification':
      return handleSendNotification(payload);
    default:
      return jsonError("Unknown action: " + action);
  }
}

function handleSendNotification(payload) {
    var p = payload.params || {};
    if (!p.token || !p.title || !p.body) return jsonError("Missing parameters (token, title, or body)");

    try {
        var res = sendFcmMessage(p.token, p.title, p.body, p.data);
        return jsonSuccess({
            response: res.getContentText()
        });
    } catch (e) {
        return jsonError(e.toString());
    }
}
