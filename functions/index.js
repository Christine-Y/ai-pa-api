const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

exports.sendTextMessage = functions.firestore
    .document('messages/{messageId}')
    .onCreate(async (snap, context) => {
        const messageData = snap.data();
        const messageId = context.params.messageId;

        try {
            // Send the message using Firebase Cloud Messaging
            const message = {
                token: messageData.to,
                notification: {
                    title: 'New Message',
                    body: messageData.message,
                },
                data: {
                    messageId: messageId,
                    timestamp: messageData.timestamp.toDate().toISOString(),
                },
            };

            const response = await admin.messaging().send(message);

            // Update the message status in Firestore
            await snap.ref.update({
                status: 'sent',
                fcmResponse: response,
            });

            return null;
        } catch (error) {
            // Update the message status to failed
            await snap.ref.update({
                status: 'failed',
                error: error.message,
            });

            throw error;
        }
    });

// API endpoint to send a message
exports.sendMessage = functions.https.onRequest(async (req, res) => {
  // Enable CORS
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'POST');
  res.set('Access-Control-Allow-Headers', 'Content-Type');

  // Handle preflight requests
  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }

  // Only allow POST requests
  if (req.method !== 'POST') {
    res.status(405).send('Method Not Allowed');
    return;
  }

  try {
    const { destinationID, text } = req.body;

    // Validate input
    if (!destinationID || !text) {
      res.status(400).send('Missing required fields: destinationID and text');
      return;
    }

    // Add message to Firestore
    const messageRef = await admin.firestore().collection('messages').add({
      text,
      destinationID,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Return success response
    res.status(200).json({
      success: true,
      messageId: messageRef.id,
    });
  } catch (error) {
    console.error('Error sending message:', error);
    res.status(500).send('Internal Server Error');
  }
}); 