import os
import firebase_admin
from firebase_admin import credentials, messaging
from app.core.config import settings
import logging

logger = logging.getLogger(__name__)

# Initialize Firebase Admin SDK if a credentials file is present.
# The user needs to supply this file manually.
FIREBASE_CREDENTIALS_PATH = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(__file__))), "firebase-adminsdk.json")

def _init_firebase():
    if not firebase_admin._apps:
        if os.path.exists(FIREBASE_CREDENTIALS_PATH):
            try:
                cred = credentials.Certificate(FIREBASE_CREDENTIALS_PATH)
                firebase_admin.initialize_app(cred)
                logger.info("Firebase Admin SDK initialized successfully.")
            except Exception as e:
                logger.error(f"Failed to initialize Firebase Admin SDK: {e}")
        else:
            logger.warning(f"Firebase credentials not found at {FIREBASE_CREDENTIALS_PATH}. Push notifications will not be sent.")

_init_firebase()

def send_push_notification(token: str, title: str, body: str, data: dict | None = None) -> bool:
    """
    Sends a push notification to a specific FCM token.
    Returns True if successful, False otherwise.
    """
    if not firebase_admin._apps:
        logger.warning("Firebase Admin SDK is not initialized. Cannot send push notification.")
        return False
        
    if not token:
        return False

    try:
        message = messaging.Message(
            notification=messaging.Notification(
                title=title,
                body=body,
            ),
            data=data or {},
            token=token,
        )
        response = messaging.send(message)
        logger.info(f"Successfully sent push notification: {response}")
        return True
    except Exception as e:
        logger.error(f"Error sending push notification: {e}")
        return False
