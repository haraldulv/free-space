#!/bin/bash
# Test om Stripe-kontoen kan opprette en Checkout-session med Vipps som
# payment method. Kjøres for å verifisere om vipps_payments-capability
# allerede er aktiv på kontoen, eller om vi må kontakte Stripe Support.
#
# Bruk:
#   STRIPE_SECRET_KEY=sk_test_... ./scripts/test-vipps-stripe.sh
#
# Eller hvis Stripe CLI er installert og logget inn:
#   ./scripts/test-vipps-stripe.sh
#
# Output:
#   - "id": "cs_test_..."  → Vipps fungerer, capability er aktiv
#   - "code": "..."        → Capability mangler, send Support-request

set -e

if [ -z "$STRIPE_SECRET_KEY" ]; then
  if command -v stripe >/dev/null 2>&1; then
    STRIPE_SECRET_KEY=$(stripe config --list 2>/dev/null | grep test_mode_api_key | head -1 | awk -F"'" '{print $2}')
  fi
fi

if [ -z "$STRIPE_SECRET_KEY" ]; then
  echo "❌ STRIPE_SECRET_KEY mangler."
  echo "   Sett den enten som env var:"
  echo "     STRIPE_SECRET_KEY=sk_test_... ./scripts/test-vipps-stripe.sh"
  echo "   Eller logg inn på Stripe CLI:"
  echo "     stripe login"
  exit 1
fi

echo "→ Kaller Stripe Checkout-API med vipps_preview=v1..."
echo

curl -s https://api.stripe.com/v1/checkout/sessions \
  -u "${STRIPE_SECRET_KEY}:" \
  -H "Stripe-Version: 2026-04-22.preview; vipps_preview=v1" \
  -d "payment_method_types[]=vipps" \
  -d mode=payment \
  -d "line_items[0][price_data][currency]=nok" \
  -d "line_items[0][price_data][product_data][name]=Test" \
  -d "line_items[0][price_data][unit_amount]=2000" \
  -d "line_items[0][quantity]=1" \
  -d "success_url=https://www.tuno.no" \
  | python3 -m json.tool
