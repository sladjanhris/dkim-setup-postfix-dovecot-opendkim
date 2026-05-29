#!/bin/bash

# ===== CONFIG =====
DOMAINS_FILE="domains.txt"
DKIM_BASE="/etc/dkimkeys"
OPENDKIM_USER="opendkim"
OPENDKIM_GROUP="opendkim"
SELECTOR="default"

# Ensure base directory exists
mkdir -p "$DKIM_BASE"
touch "$DKIM_BASE/KeyTable" "$DKIM_BASE/SigningTable" "$DKIM_BASE/TrustedHosts"

chmod 644 "$DKIM_BASE/KeyTable" "$DKIM_BASE/SigningTable" "$DKIM_BASE/TrustedHosts"

echo "=== DKIM Automation Script ==="

# Check domains.txt
if [ ! -f "$DOMAINS_FILE" ]; then
    echo "❌ ERROR: $DOMAINS_FILE not found!"
    exit 1
fi

# Read domains from file
while IFS= read -r DOMAIN; do
    # Skip empty lines
    [ -z "$DOMAIN" ] && continue

    echo ""
    echo "Processing: $DOMAIN"

    DOMAIN_DIR="$DKIM_BASE/$DOMAIN"
    mkdir -p "$DOMAIN_DIR"

    # Generate DKIM keys only if missing
    if [ ! -f "$DOMAIN_DIR/$SELECTOR.private" ]; then
        echo "  Generating DKIM keys..."
        opendkim-genkey -D "$DOMAIN_DIR" -d "$DOMAIN" -s "$SELECTOR"
    else
        echo "  Keys already exist, skipping generation."
    fi

    # Fix permissions
    chmod 700 "$DOMAIN_DIR"
    chmod 600 "$DOMAIN_DIR/$SELECTOR.private"
    chown -R $OPENDKIM_USER:$OPENDKIM_GROUP "$DOMAIN_DIR"

    # Build KeyTable entry
    KEYTABLE_LINE="$SELECTOR._domainkey.$DOMAIN $DOMAIN:$SELECTOR:$DOMAIN_DIR/$SELECTOR.private"
    if ! grep -Fxq "$KEYTABLE_LINE" "$DKIM_BASE/KeyTable"; then
        echo "$KEYTABLE_LINE" >> "$DKIM_BASE/KeyTable"
        echo "  Added KeyTable entry."
    else
        echo "  KeyTable entry exists."
    fi

    # Build SigningTable entry
    SIGNING_LINE="*@$DOMAIN $SELECTOR._domainkey.$DOMAIN"
    if ! grep -Fxq "$SIGNING_LINE" "$DKIM_BASE/SigningTable"; then
        echo "$SIGNING_LINE" >> "$DKIM_BASE/SigningTable"
        echo "  Added SigningTable entry."
    else
        echo "  SigningTable entry exists."
    fi

    # Add TrustedHosts entry
    if ! grep -Fxq "$DOMAIN" "$DKIM_BASE/TrustedHosts"; then
        echo "$DOMAIN" >> "$DKIM_BASE/TrustedHosts"
        echo "  Added to TrustedHosts."
    else
        echo "  TrustedHosts entry exists."
    fi

done < "$DOMAINS_FILE"

echo ""
echo "Restarting OpenDKIM & Postfix..."
systemctl restart opendkim
systemctl reload postfix

echo ""
echo "=== Completed Successfully === ==="
echo "Public DKIM keys saved under: /etc/dkimkeys/<domain>/default.txt"
