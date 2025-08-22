# Evolution API Integration

This document describes the Evolution API integration with Chatwoot, which allows connecting WhatsApp instances through QR Code or phone number pairing.

## Overview

The Evolution API integration provides:
- Automatic WhatsApp instance management
- QR Code and phone number connection methods
- WhatsApp behavior configuration
- Real-time connection status monitoring
- Webhook integration for message processing

## Configuration

### Environment Variables

Add the following environment variables to your `.env` file:

```bash
# Evolution API Configuration
EVOLUTION_API_URL_V2=https://evo.cordex.ai
EVOLUTION_API_KEY=your_evolution_api_key
FRONTEND_URL=https://your-chatwoot-domain.com
```

**Note**: The `CHATWOOT_TOKEN` is now dynamically obtained from the current user's access token. Each user has their own unique access token that is used for Evolution API integration, ensuring proper user-specific authentication.

### Required Variables

- `EVOLUTION_API_URL_V2`: The base URL of your Evolution API instance
- `EVOLUTION_API_KEY`: API key for authenticating with Evolution API
- `CHATWOOT_TOKEN`: Token used by Evolution API to send webhooks to Chatwoot
- `FRONTEND_URL`: Your Chatwoot frontend URL (used as chatwootUrl in Evolution API)

## Features

### WhatsApp QR Code Tab

For API Channel inboxes, a new "WhatsApp QR Code" tab is available in the inbox settings. This tab provides:

1. **Instance Management**
   - Automatic creation of Evolution API instances
   - Instance name format: `{account_id}_{inbox_id}_{inbox_identifier}`
   - Webhook URL storage in the database

2. **Connection Methods**
   - **QR Code**: Generate and display QR code for WhatsApp scanning
   - **Phone Number**: Enter phone number to receive pairing code

3. **Configuration Options**
   - Reject calls automatically
   - Custom call rejection message
   - Ignore group messages
   - Always show as online
   - Auto-read messages
   - Show read receipts
   - Sync full message history

4. **Real-time Status**
   - Connection status monitoring (every 5 seconds)
   - Visual indicators for connected/disconnected states
   - Automatic UI updates based on connection state

## API Endpoints

### Chatwoot API Endpoints

The following endpoints are available for managing Evolution WhatsApp integration:

- `POST /api/v1/accounts/{account_id}/inboxes/{inbox_id}/evolution_whatsapp/initialize_instance`
- `GET /api/v1/accounts/{account_id}/inboxes/{inbox_id}/evolution_whatsapp/connection_status`
- `POST /api/v1/accounts/{account_id}/inboxes/{inbox_id}/evolution_whatsapp/connect_qr_code`
- `POST /api/v1/accounts/{account_id}/inboxes/{inbox_id}/evolution_whatsapp/connect_with_number`
- `PATCH /api/v1/accounts/{account_id}/inboxes/{inbox_id}/evolution_whatsapp/update_settings`
- `GET /api/v1/accounts/{account_id}/inboxes/{inbox_id}/evolution_whatsapp/webhook_info`

### Webhook Endpoint

Evolution API sends webhooks to:
- `POST /webhooks/evolution/{instance_name}`

## Database Changes

### Channel::Api Model

The `Channel::Api` model has been extended with the following methods:

- `evolution_webhook_configured?`: Check if Evolution webhook is configured
- `evolution_instance_name`: Extract instance name from webhook URL
- `has_evolution_instance?`: Check if Evolution instance exists
- `generate_evolution_instance_name`: Generate instance name for new instances
- `evolution_webhook_url`: Generate webhook URL for Evolution API

## Usage

### Setting up WhatsApp Connection

1. Navigate to your API Channel inbox settings
2. Click on the "WhatsApp QR Code" tab
3. The system will automatically create an Evolution API instance
4. Choose connection method:
   - **QR Code**: Click "Connect with QR Code" and scan the displayed QR code with WhatsApp
   - **Phone Number**: Click "Connect with Phone Number", enter your number, and use the pairing code

### Configuring WhatsApp Behavior

Once connected, you can configure various WhatsApp behaviors:

1. **Call Management**: Enable automatic call rejection with custom message
2. **Group Messages**: Choose whether to ignore group messages
3. **Online Status**: Set always online status
4. **Message Reading**: Configure automatic message reading and read receipts
5. **History Sync**: Enable full message history synchronization

### Monitoring Connection

The interface automatically monitors the connection status and updates every 5 seconds. You'll see:
- Green badge when connected
- Red badge when disconnected
- Real-time status updates

## Troubleshooting

### Common Issues

1. **Instance Creation Failed**
   - Check Evolution API URL and key configuration
   - Verify network connectivity to Evolution API
   - Check Evolution API logs

2. **QR Code Not Generating**
   - Ensure instance is created successfully
   - Check Evolution API instance status
   - Verify API permissions

3. **Connection Not Establishing**
   - Ensure QR code is scanned within time limit
   - Check WhatsApp app version compatibility
   - Verify phone number format for pairing code method

4. **Webhook Not Receiving Messages**
   - Verify webhook URL is correctly configured
   - Check Chatwoot webhook endpoint accessibility
   - Ensure Evolution API can reach Chatwoot instance

### Logs

Check the following logs for debugging:
- Rails logs: `log/production.log` or `log/development.log`
- Evolution API logs (check your Evolution API instance)
- Browser console for frontend issues

## Security Considerations

1. **API Keys**: Keep Evolution API keys secure and rotate regularly
2. **Webhook Security**: Consider implementing webhook signature verification
3. **Network Security**: Use HTTPS for all communications
4. **Access Control**: Limit access to Evolution API endpoints

## Limitations

1. **Single Instance per Inbox**: Each API Channel inbox can have only one Evolution instance
2. **WhatsApp Business API**: This integration is for WhatsApp Business API, not regular WhatsApp
3. **Message Types**: Currently supports basic message types (text, images, documents)
4. **Group Management**: Limited group message handling capabilities

## Support

For issues related to:
- **Chatwoot Integration**: Check Chatwoot documentation and support channels
- **Evolution API**: Refer to Evolution API documentation and support
- **WhatsApp Business API**: Consult WhatsApp Business API documentation
