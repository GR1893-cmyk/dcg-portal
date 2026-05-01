/**
 * DCG PORTAL — Google Apps Script Email Relay
 * =============================================
 * הוראות התקנה:
 *   1. כנס ל-https://script.google.com
 *   2. לחץ "New project"
 *   3. מחק את הקוד הקיים והדבק את כל הקוד הזה
 *   4. שמור (Ctrl+S)
 *   5. לחץ "Deploy" → "New deployment"
 *   6. בחר: Execute as = Me | Who has access = Anyone
 *   7. לחץ "Deploy" → אשר הרשאות → העתק את ה-URL
 *   8. הדבק את ה-URL בתוך index.html במקום: PASTE_YOUR_GOOGLE_APPS_SCRIPT_URL_HERE
 */

const SECRET = 'DCG-PORTAL-2026';
const TO_EMAIL = 'einav@dcg-tech.com';

function doPost(e) {
  try {
    const data = JSON.parse(e.postData.contents);

    // Basic authentication
    if (data.secret !== SECRET) {
      return jsonResponse({ error: 'Unauthorized' });
    }

    // Decode the base64 Excel attachment
    const decoded = Utilities.base64Decode(data.attachment);
    const blob = Utilities.newBlob(
      decoded,
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      data.filename
    );

    // Send email via Gmail
    GmailApp.sendEmail(TO_EMAIL, data.subject, data.body, {
      attachments: [blob],
      name: 'DCG Portal',
    });

    return jsonResponse({ success: true });

  } catch (err) {
    return jsonResponse({ error: err.toString() });
  }
}

function jsonResponse(obj) {
  return ContentService
    .createTextOutput(JSON.stringify(obj))
    .setMimeType(ContentService.MimeType.JSON);
}
