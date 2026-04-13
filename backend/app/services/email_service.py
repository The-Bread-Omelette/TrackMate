import os
import json
import base64
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from google.auth.transport.requests import Request
from google.oauth2.credentials import Credentials
from googleapiclient.discovery import build
from app.core.config import settings

class EmailService:
    def __init__(self):
        self.scopes = ['https://www.googleapis.com/auth/gmail.send']
        self.creds = None
        self._authenticate()

    def _authenticate(self):
        """Loads credentials from Render Environment Variables OR local token.json"""
        
        # 1. Try to load from Render Environment Variable first
        token_env = os.environ.get('GOOGLE_TOKEN_JSON')
        
        if token_env:
            try:
                token_info = json.loads(token_env)
                self.creds = Credentials.from_authorized_user_info(token_info, self.scopes)
                print("[Email] Loaded Google credentials from Environment Variable.")
            except Exception as e:
                print(f"[Email] Failed to parse GOOGLE_TOKEN_JSON env var: {e}")
                
        # 2. Fallback to local token.json file (for local development)
        elif os.path.exists('token.json'):
            self.creds = Credentials.from_authorized_user_file('token.json', self.scopes)
            print("[Email] Loaded Google credentials from local token.json file.")
            
        # 3. Handle initial token refresh if it has already expired on boot
        self._refresh_if_needed()

    def _refresh_if_needed(self):
        """Checks if the current access token is expired and refreshes it if a refresh token is available."""
        if self.creds and not self.creds.valid:
            if self.creds.expired and self.creds.refresh_token:
                try:
                    self.creds.refresh(Request())
                    print("[Email] Google access token refreshed successfully.")
                    
                    # If we are local, update the physical file
                    if os.path.exists('token.json'):
                        with open('token.json', 'w') as token:
                            token.write(self.creds.to_json())
                except Exception as e:
                    print(f"[Email] Failed to refresh token: {e}")
            else:
                print("[Email] ERROR: Missing or invalid Google credentials. Cannot send emails.")
        elif not self.creds:
             print("[Email] ERROR: No Google credentials found in Environment or local file.")

    def _send(self, to: str, subject: str, html: str) -> None:
        if not settings.email_enabled:
            print(f"[Email disabled] To: {to} | Subject: {subject}")
            return

        # Ensure the token is refreshed right before we attempt to send
        self._refresh_if_needed()

        if not self.creds or not self.creds.valid:
            print(f"[Email] Auth failed. Skipping email to {to}")
            return

        print(f"[Email] Sending via Gmail API to {to}")
        
        try:
            # Build the Gmail API service
            service = build('gmail', 'v1', credentials=self.creds)
            
            # Create the email message
            message = MIMEMultipart("alternative")
            message['To'] = to
            message['From'] = f"{settings.EMAIL_FROM_NAME} <{settings.EMAIL_FROM}>"
            message['Subject'] = subject
            message.attach(MIMEText(html, 'html'))
            
            # Encode as base64url, which the Gmail API requires
            raw_message = base64.urlsafe_b64encode(message.as_bytes()).decode()
            body = {'raw': raw_message}
            
            # Send it! 'me' is a special keyword for the authenticated user
            sent_message = service.users().messages().send(userId='me', body=body).execute()
            print(f"[Email] Sent successfully! Message ID: {sent_message['id']}")
            
        except Exception as e:
            print(f"[Email] Failed to send via Gmail API: {e}")
            raise

    def send_verification_email(self, to: str, full_name: str, otp: str) -> None:
        html = f"""
        <p>Hi {full_name},</p>
        <p>Your TrackMate verification code is:</p>
        <h2 style="letter-spacing: 8px; font-size: 32px; color: #2563EB;">{otp}</h2>
        <p>This code expires in 10 minutes.</p>
        <p>— TrackMate</p>
        """
        self._send(to, "Your TrackMate verification code", html)
        
    def send_trainer_approved_email(self, to: str, full_name: str) -> None:
        html = f"""
        <p>Hi {full_name},</p>
        <p>Your trainer application has been <strong>approved</strong>.</p>
        <p>You can now log in as a trainer and start managing trainees.</p>
        <p>— TrackMate</p>
        """
        self._send(to, "Your trainer application was approved", html)

    def send_trainer_rejected_email(self, to: str, full_name: str) -> None:
        html = f"""
        <p>Hi {full_name},</p>
        <p>Unfortunately your trainer application was not approved at this time.</p>
        <p>Contact support if you believe this is a mistake.</p>
        <p>— TrackMate</p>
        """
        self._send(to, "Your trainer application was not approved", html)
        
    def send_password_reset_email(self, email: str, name: str, otp: str):
        html = f"""
        <p>Hi {name},</p>
        <p>You requested a password reset. Your OTP is:</p>
        <h2 style="letter-spacing: 8px; font-size: 32px; color: #2563EB;">{otp}</h2>
        <p>This OTP will expire in 10 minutes.</p>
        <p>If you did not request this, please ignore this email.</p>
        <p>— TrackMate</p>
        """
        self._send(email, "Password Reset Request", html)

email_service = EmailService()