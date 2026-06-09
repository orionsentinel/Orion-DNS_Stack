#!/usr/bin/env python3
"""
Signal Webhook Bridge
Receives webhook calls from Alertmanager and forwards them to signal-cli-rest-api
"""
from flask import Flask, request, jsonify
import requests
import os
import json
import logging

app = Flask(__name__)
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Configuration from environment variables
SIGNAL_CLI_REST_API_URL = os.environ.get('SIGNAL_CLI_REST_API_URL', 'http://signal-cli-rest-api:8080')
SIGNAL_NUMBER = os.environ.get('SIGNAL_NUMBER', '')  # The number registered with signal-cli
SIGNAL_RECIPIENTS = os.environ.get('SIGNAL_RECIPIENTS', '')  # Comma-separated list of recipient numbers

@app.route('/health')
def health():
    """Health check endpoint"""
    try:
        # Check if signal-cli-rest-api is reachable
        response = requests.get(f"{SIGNAL_CLI_REST_API_URL}/v1/health", timeout=5)
        signal_healthy = response.status_code == 200
    except:
        signal_healthy = False
    
    return jsonify({
        'status': 'healthy' if signal_healthy else 'degraded',
        'service': 'signal-webhook-bridge',
        'signal_cli_api': 'reachable' if signal_healthy else 'unreachable'
    })

@app.route('/v1/send', methods=['POST'])
def send_signal():
    """
    Receive webhook from Alertmanager and forward to Signal
    """
    try:
        data = request.json
        logger.info(f"Received webhook: {json.dumps(data, indent=2)}")
        
        # Extract alerts from Alertmanager payload
        if 'alerts' not in data:
            return jsonify({'error': 'No alerts in payload'}), 400
            
        alerts = data['alerts']
        if not alerts:
            return jsonify({'status': 'no alerts to send'}), 200
        
        # Format message for Signal
        messages = []
        for alert in alerts:
            status = alert.get('status', 'unknown')
            alertname = alert.get('labels', {}).get('alertname', 'Unknown Alert')
            severity = alert.get('labels', {}).get('severity', 'info')
            description = alert.get('annotations', {}).get('description', 'No description')
            
            emoji = '🔴' if status == 'firing' else '✅'
            message = f"{emoji} {alertname}\n"
            message += f"Status: {status.upper()}\n"
            message += f"Severity: {severity.upper()}\n"
            message += f"Description: {description}"
            messages.append(message)
        
        combined_message = "\n\n".join(messages)
        
        # Send to Signal via signal-cli-rest-api
        if not SIGNAL_NUMBER or not SIGNAL_RECIPIENTS:
            logger.warning("Signal credentials not configured, skipping send")
            return jsonify({
                'status': 'skipped',
                'reason': 'credentials not configured',
                'message': combined_message
            }), 200
        
        # Parse recipients
        recipients = [r.strip() for r in SIGNAL_RECIPIENTS.split(',') if r.strip()]
        
        # Send message via signal-cli-rest-api v2 API
        payload = {
            "message": combined_message,
            "number": SIGNAL_NUMBER,
            "recipients": recipients
        }
        
        logger.info(f"Sending to Signal: {combined_message[:100]}...")
        response = requests.post(
            f"{SIGNAL_CLI_REST_API_URL}/v2/send",
            json=payload,
            headers={'Content-Type': 'application/json'},
            timeout=30
        )
        
        if response.status_code in [200, 201]:
            logger.info("Successfully sent to Signal")
            return jsonify({'status': 'sent', 'message': combined_message}), 200
        else:
            logger.error(f"Failed to send to Signal: {response.status_code} - {response.text}")
            return jsonify({
                'status': 'failed',
                'error': response.text,
                'message': combined_message
            }), 500
            
    except Exception as e:
        logger.error(f"Error processing webhook: {str(e)}", exc_info=True)
        return jsonify({'error': 'An internal error occurred'}), 500

@app.route('/test', methods=['POST'])
def test_notification():
    """Test endpoint to send a test notification"""
    try:
        message = request.json.get('message', 'Test notification from RPi HA DNS Stack') if request.json else 'Test notification from RPi HA DNS Stack'
        
        if not SIGNAL_NUMBER or not SIGNAL_RECIPIENTS:
            return jsonify({
                'status': 'error',
                'message': 'Signal credentials not configured'
            }), 400
        
        # Parse recipients
        recipients = [r.strip() for r in SIGNAL_RECIPIENTS.split(',') if r.strip()]
        
        payload = {
            "message": message,
            "number": SIGNAL_NUMBER,
            "recipients": recipients
        }
        
        response = requests.post(
            f"{SIGNAL_CLI_REST_API_URL}/v2/send",
            json=payload,
            headers={'Content-Type': 'application/json'},
            timeout=30
        )
        
        if response.status_code in [200, 201]:
            return jsonify({'status': 'sent', 'message': message}), 200
        else:
            return jsonify({
                'status': 'failed',
                'error': response.text
            }), 500
            
    except Exception as e:
        logger.error(f"Error sending test notification: {str(e)}")
        return jsonify({'error': 'An internal error occurred'}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080)
