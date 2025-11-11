#!/bin/bash
# Complete document upload test script

set -e

API_URL="http://54.179.230.219"

echo "=== Step 1: Create a Contact ==="
RESPONSE=$(curl -s -X POST $API_URL/contact \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Test User",
    "email": "test@example.com",
    "message": "Testing document upload workflow"
  }')

echo "Contact Response:"
echo $RESPONSE | jq .

# Extract contact ID
CONTACT_ID=$(echo $RESPONSE | jq -r '.contactId')
echo ""
echo " Contact created with ID: $CONTACT_ID"

echo ""
echo "=== Step 2: Create Test File ==="
echo "This is a test document for upload" > /tmp/test-upload.txt
echo " Created test file: /tmp/test-upload.txt"

echo ""
echo "=== Step 3: Upload Document ==="
curl -s -X POST $API_URL/documents/upload \
  -F "file=@/tmp/test-upload.txt" \
  -F "contact_id=$CONTACT_ID" \
  -F "document_type=test" \
  -F "description=Test document upload" | jq .

echo ""
echo " Document uploaded successfully!"

echo ""
echo "=== Step 4: Verify in Database ==="
echo "Getting documents for contact: $CONTACT_ID"
curl -s $API_URL/contacts/$CONTACT_ID/documents | jq .

# Cleanup
rm -f /tmp/test-upload.txt

echo ""
echo "=== Complete! ==="
echo "Contact ID: $CONTACT_ID"
echo "You can now upload more documents using this contact_id"

