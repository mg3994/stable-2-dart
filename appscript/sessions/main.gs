/**
 * SESSIONS Project
 * Handles User Authentication, JWT Verification, and Session Management.
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
    case 'verifyToken':
      return handleVerifyFirebaseToken(payload);
    case 'logoutDevice':
      return handleLogoutDevice(payload);
    default:
      return jsonError("Unknown action: " + action);
  }
}

function handleVerifyFirebaseToken(payload) {
  var authResult = verifyFirebaseToken(payload.idToken);
  if (!authResult.isValid) return jsonError(authResult.error);

  // Logic to store/update session in Spreadsheet could go here
  return jsonSuccess({ user: authResult });
}

function handleLogoutDevice(payload) {
  if (!payload.clientId) return jsonError("Client ID missing");

  return withLock(function() {
    var settings = getSettings();
    var ss = SpreadsheetApp.openById(settings.SPREADSHEET_ID_SESSION);
    var sheet = ss.getSheetByName("sessions") || ss.insertSheet("sessions");
    var data = sheet.getDataRange().getValues();

    for (var i = 1; i < data.length; i++) {
      if (data[i][0] === payload.clientId) { // Assuming index 0 is clientId
        sheet.getRange(i + 1, 2).setValue("guest");
        sheet.getRange(i + 1, 3).setValue("");
        sheet.getRange(i + 1, 5).setValue(new Date().toISOString());
        break;
      }
    }
    return jsonSuccess({ loggedOut: true });
  });
}
