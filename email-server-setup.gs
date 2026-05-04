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
 *
 * עדכון קיים: אם כבר יש deployment פעיל, לחץ "Deploy" → "Manage deployments"
 *   → ערוך את הגרסה הקיימת → פרסם גרסה חדשה.
 */

const SECRET    = 'DCG-PORTAL-2026';
const TO_EMAIL  = 'einav@dcg-tech.com';

function doPost(e) {
  try {
    const data = JSON.parse(e.postData.contents);

    // Basic authentication
    if (data.secret !== SECRET) {
      return jsonResponse({ error: 'Unauthorized' });
    }

    // Decode the base64 Excel attachment
    const decoded = Utilities.base64Decode(data.attachment);
    const excelBlob = Utilities.newBlob(
      decoded,
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      data.filename
    );

    // Build attachments array: Excel first, then any receipts
    const attachments = [excelBlob];

    if (data.extraAttachments && Array.isArray(data.extraAttachments)) {
      data.extraAttachments.forEach(function(att) {
        try {
          if (!att.data) return; // skip empty
          const bytes = Utilities.base64Decode(att.data);
          const blob  = Utilities.newBlob(bytes, att.mimeType || 'application/octet-stream', att.filename || 'קבלה');
          attachments.push(blob);
        } catch (attachErr) {
          Logger.log('Failed to decode attachment: ' + att.filename + ' — ' + attachErr);
        }
      });
    }

    // Send email via Gmail with all attachments
    GmailApp.sendEmail(TO_EMAIL, data.subject, data.body, {
      attachments: attachments,
      name: 'DCG Portal',
    });

    Logger.log('Email sent to ' + TO_EMAIL + ' with ' + attachments.length + ' attachment(s).');
    return jsonResponse({ success: true, attachments: attachments.length });

  } catch (err) {
    Logger.log('doPost error: ' + err);
    return jsonResponse({ error: err.toString() });
  }
}

function jsonResponse(obj) {
  return ContentService
    .createTextOutput(JSON.stringify(obj))
    .setMimeType(ContentService.MimeType.JSON);
}
