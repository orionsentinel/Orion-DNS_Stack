# Signal Integration Guide - signal-cli-rest-api

## Overview

This stack uses [signal-cli-rest-api](https://github.com/bbernhard/signal-cli-rest-api) for Signal notifications. This is a self-hosted solution that provides full control over your Signal messaging without relying on third-party services.

## Architecture

```
Alertmanager/AI-Watchdog → Signal Bridge → signal-cli-rest-api → Signal Network → Signal App
```

## Initial Setup

### 1. Register Phone Number with Signal

You need to register a phone number with Signal. This can be a dedicated number for notifications or your existing Signal number.

**Start the signal-cli-rest-api service:**
```bash
cd /opt/rpi-ha-dns-stack/stacks/observability
sudo docker compose up -d signal-cli-rest-api
```

**Register your number (replace +1234567890 with your number):**
```bash
# Request verification code
curl -X POST "http://192.168.8.250:8081/v1/register/+1234567890" \
  -H 'Content-Type: application/json'

# You will receive an SMS with a verification code
# Verify with the code you received
curl -X POST "http://192.168.8.250:8081/v1/register/+1234567890/verify/YOUR-CODE" \
  -H 'Content-Type: application/json'
```

**Alternative: Link to existing Signal account (CAPTCHA required):**
```bash
# Generate QR code for linking
curl -X GET "http://192.168.8.250:8081/v1/qrcodelink?device_name=rpi-dns-stack"

# This will return a QR code image and linking URL
# Open your Signal app -> Settings -> Linked Devices -> + -> Scan QR code
```

### 2. Configure Environment Variables

Edit your `.env` file:
```bash
cd /opt/rpi-ha-dns-stack
sudo nano .env
```

Set these variables:
```bash
# The phone number you registered with signal-cli
SIGNAL_NUMBER=+1234567890

# Who should receive notifications (comma-separated for multiple recipients)
SIGNAL_RECIPIENTS=+1234567890,+0987654321
```

### 3. Deploy Services

```bash
cd /opt/rpi-ha-dns-stack/stacks/observability
sudo docker compose up -d
```

### 4. Test Notification

```bash
curl -X POST http://192.168.8.250:8080/test \
  -H "Content-Type: application/json" \
  -d '{"message": "🎉 Signal integration is working!"}'
```

You should receive a Signal message on your phone!

## Key Features

✅ **Self-Hosted** - No dependency on third-party services
✅ **Full Control** - Complete control over your Signal messaging
✅ **Secure** - End-to-end encrypted Signal protocol
✅ **Reliable** - Direct connection to Signal network
✅ **Multiple Recipients** - Send to multiple phone numbers
✅ **Group Support** - Can send to Signal groups
✅ **Attachments** - Support for sending images and files

## Service Endpoints

| Service | URL | Purpose |
|---------|-----|---------|
| Signal CLI REST API | http://192.168.8.250:8081 | Direct Signal API access |
| Signal Bridge Health | http://192.168.8.250:8080/health | Health check |
| Signal Bridge Test | http://192.168.8.250:8080/test | Send test notification |
| Alertmanager | http://192.168.8.250:9093 | View alerts |
| Prometheus | http://192.168.8.250:9090 | Metrics & alerting |

## Advanced Configuration

### Send to Signal Groups

1. Create a group in Signal app with the registered number
2. Get the group ID:
```bash
curl http://192.168.8.250:8081/v1/groups/+1234567890
```

3. Update alertmanager or use group ID in API calls

### Trust New Identities Automatically

For production use, you may want to trust new identities automatically:
```bash
curl -X PUT "http://192.168.8.250:8081/v1/configuration" \
  -H 'Content-Type: application/json' \
  -d '{"trust_new_identities": "always"}'
```

### Persistent Configuration

The Signal configuration is stored in `./signal-cli-config` directory and persisted across container restarts. This includes:
- Registered phone number
- Encryption keys
- Trusted identities
- Message history

## How It Works

### Alertmanager Flow
1. Prometheus detects an issue and fires an alert
2. Alert is sent to Alertmanager
3. Alertmanager sends webhook to signal-webhook-bridge (port 8080)
4. Bridge formats the message and sends to signal-cli-rest-api (port 8081)
5. signal-cli-rest-api sends via Signal protocol
6. Recipients receive end-to-end encrypted notification

### AI-Watchdog Flow
1. AI-Watchdog detects a stopped container
2. Container is restarted
3. Watchdog sends notification to signal-webhook-bridge
4. Bridge forwards to signal-cli-rest-api
5. Recipients receive restart notification

## Notification Examples

**Container Restart:**
```
🔧 AI-Watchdog: Restarted containers: pihole1, unbound1
```

**Prometheus Alert:**
```
🔴 HighMemoryUsage
Status: FIRING
Severity: WARNING
Description: Container memory usage is above 90%
```

## Troubleshooting

### Registration fails?
- Ensure the phone number format includes country code (+1234567890)
- Check if the number is already registered with Signal
- Try using the QR code linking method instead

### No notifications received?
```bash
# Check signal-cli-rest-api health
curl http://192.168.8.250:8081/v1/health

# Check if number is registered
curl http://192.168.8.250:8081/v1/accounts

# Check bridge health
curl http://192.168.8.250:8080/health

# View logs
docker logs signal-cli-rest-api
docker logs signal-webhook-bridge
```

### "Untrusted identity" errors?
Trust the identity manually:
```bash
curl -X POST "http://192.168.8.250:8081/v1/identities/+1234567890/trust/IDENTITY_KEY"
```

Or enable automatic trust (see Advanced Configuration above).

### Service not starting?
```bash
# Check configuration
docker compose config

# Check logs
docker compose logs signal-cli-rest-api
docker compose logs signal-webhook-bridge

# Restart services
docker compose restart signal-cli-rest-api signal-webhook-bridge
```

## Security Best Practices

- ✅ Keep your Signal number's private key secure (in `signal-cli-config`)
- ✅ Use a dedicated number for notifications if possible
- ✅ Regularly backup the `signal-cli-config` directory
- ✅ Restrict access to port 8081 (Signal CLI API) using firewall rules
- ✅ Use port 8080 (Signal Bridge) for internal services only

## API Documentation

For full API documentation, visit:
- Signal CLI REST API: https://bbernhard.github.io/signal-cli-rest-api/
- Interactive API docs: http://192.168.8.250:8081/api-docs

## Support

For issues or questions:
- signal-cli-rest-api: https://github.com/bbernhard/signal-cli-rest-api/issues
- This repository: https://github.com/orionsentinel/Orion-DNS_Stack/issues
