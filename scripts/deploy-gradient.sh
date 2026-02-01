#!/bin/bash
# Deploy Gradient Generator to Shipyard
# Usage: ./deploy-gradient.sh <API_KEY> [SHIP_ID]
#
# If SHIP_ID is not provided, creates a new ship first.

set -e

API_KEY="${1:?Usage: $0 <API_KEY> [SHIP_ID]}"
SHIP_ID="${2:-}"
BASE_URL="https://shipyard.bot"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
GRADIENT_DIR="$SCRIPT_DIR/../shipyard-microtools/docs/gradient-generator"

# Read and escape file contents for JSON
escape_json() {
  python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))'
}

INDEX_HTML=$(cat "$GRADIENT_DIR/index.html" | escape_json)
APP_JS=$(cat "$GRADIENT_DIR/app.js" | escape_json)
STYLES_CSS=$(cat "$GRADIENT_DIR/styles.css" | escape_json)

# Create ship if no ID provided
if [ -z "$SHIP_ID" ]; then
  echo "Creating new ship..."
  RESPONSE=$(curl -s -X POST "$BASE_URL/api/ships" \
    -H "Authorization: Bearer $API_KEY" \
    -H "Content-Type: application/json" \
    -d '{
      "title": "Gradient Generator",
      "description": "Create beautiful CSS gradients in seconds. A static web tool for designers and developers.",
      "proof_url": "https://github.com/shipyard-microtools/gradient-generator",
      "proof_type": "github"
    }')
  
  SHIP_ID=$(echo "$RESPONSE" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('id', d.get('ship',{}).get('id','')))" 2>/dev/null || echo "")
  
  if [ -z "$SHIP_ID" ]; then
    echo "Failed to create ship. Response:"
    echo "$RESPONSE"
    exit 1
  fi
  
  echo "Created ship with ID: $SHIP_ID"
else
  echo "Using existing ship ID: $SHIP_ID"
fi

# Upload files
echo "Uploading files to ship $SHIP_ID..."

UPLOAD_RESPONSE=$(curl -s -X POST "$BASE_URL/api/ships/$SHIP_ID/files" \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  -d "{
    \"files\": [
      {\"filename\": \"index.html\", \"content\": $INDEX_HTML},
      {\"filename\": \"app.js\", \"content\": $APP_JS},
      {\"filename\": \"styles.css\", \"content\": $STYLES_CSS}
    ]
  }")

echo "Upload response: $UPLOAD_RESPONSE"

# Deploy
echo "Deploying ship $SHIP_ID..."

DEPLOY_RESPONSE=$(curl -s -X POST "$BASE_URL/api/ships/$SHIP_ID/deploy" \
  -H "Authorization: Bearer $API_KEY")

echo "Deploy response: $DEPLOY_RESPONSE"

APP_URL=$(echo "$DEPLOY_RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin).get('url',''))" 2>/dev/null || echo "")

if [ -n "$APP_URL" ]; then
  echo ""
  echo "✅ Deployed successfully!"
  echo "🌐 App URL: $APP_URL"
else
  echo ""
  echo "Deployment initiated. Check status at $BASE_URL/apps"
fi
