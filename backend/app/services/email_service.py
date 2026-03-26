import httpx
from app.core.config import settings

class EmailService:

    def _send(self, to: str, subject: str, html: str) -> None:
        print(f"[Email] _send called. enabled={settings.email_enabled} to={to}")
        if not settings.email_enabled:
            print(f"[Email disabled] To: {to} | Subject: {subject}")
            return

        # Fetch the API key from your settings
        api_key = getattr(settings, "RESEND_API_KEY", None)
        
        if not api_key:
            print("[Email] ERROR: RESEND_API_KEY is missing from settings.")
            raise ValueError("RESEND_API_KEY is not configured in environment variables.")

        print(f"[Email] Sending via HTTP API to {to}")
        
        # Resend API endpoint
        url = "https://api.resend.com/emails"
        
        headers = {
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json"
        }
        
        payload = {
            "from": f"{settings.EMAIL_FROM_NAME} <{settings.EMAIL_FROM}>",
            "to": [to],
            "subject": subject,
            "html": html
        }

        try:
            # We use httpx to make a secure HTTPS request over Port 443
            with httpx.Client(timeout=10.0) as client:
                response = client.post(url, headers=headers, json=payload)
                response.raise_for_status()  # Raises an exception for 4xx/5xx status codes
                
                data = response.json()
                print(f"[Email] Sent successfully to {to}. Provider ID: {data.get('id')}")
                
        except httpx.HTTPStatusError as e:
            print(f"[Email] API HTTP Error: {e.response.status_code} - {e.response.text}")
            raise
        except Exception as e:
            print(f"[Email] Request failed: {type(e).__name__}: {e}")
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


email_service = EmailService()