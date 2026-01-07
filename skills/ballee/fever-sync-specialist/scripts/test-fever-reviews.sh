#!/bin/bash
# ============================================================================
# Fever Partners Reviews API - Reverse Engineered
# ============================================================================
#
# ENDPOINT DISCOVERED:
#   GET https://services.feverup.com/b2b-partners/1.0/partners/{partner_id}/reviews
#
# QUERY PARAMETERS:
#   - items_per_page: Number of reviews per page (e.g., 10)
#   - page: Page number (1-indexed)
#   - city_id: Filter by city ID (e.g., "1004611" for Dortmund)
#   - place_id: Filter by venue ID (e.g., 23810)
#   - question_type: Type of review ("general-review")
#   - order_by: Sort field ("answered_at")
#   - order_by_direction: Sort direction ("desc" or "asc")
#
# AUTHENTICATION:
#   - Requires Authorization header: "B2bToken {token}"
#   - Token obtained via login at partners.feverup.com
#
# RESPONSE STRUCTURE:
# {
#   "data": {
#     "questions_rating": [
#       {
#         "average": "4.6",
#         "id": "uuid",
#         "number_of_ratings": 2044,
#         "title": "How would you rate the experience overall?",
#         "type": "general-review"
#       }
#     ],
#     "reviews": [
#       {
#         "answers": [
#           {
#             "flagged": false,
#             "hidden": false,
#             "id": "uuid",
#             "question_id": "uuid",
#             "question_title": "How would you rate the experience overall?",
#             "question_type": "general-review",
#             "rating": 5,
#             "reasoning": "Optional text review"
#           }
#         ],
#         "city_id": "1004611",
#         "city_name": "Dortmund",
#         "city_timezone": "Europe/Berlin",
#         "place_address": "Schützenstraße 35, Dortmund",
#         "place_id": 23810,
#         "plan_id": 416711,
#         "plan_name": "Candlelight: Tribut an Coldplay",
#         "session_name": "Zone D",
#         "session_starts_at": "2025-11-28T19:30:00Z",
#         "ticket_id": 100585215,
#         "user_first_name": "Alexandra",
#         "user_id": 82692035,
#         "user_image_url": "https://...",
#         "user_last_name": "Dröge"
#       }
#     ]
#   }
# }
# ============================================================================

# Configuration
PARTNER_ID="${FEVER_PARTNER_ID:-8486}"  # Replace with your partner ID
CITY_ID="${1:-1004611}"                  # Default: Dortmund
PLACE_ID="${2:-23810}"                   # Default: venue ID
PAGE="${3:-1}"
ITEMS_PER_PAGE="${4:-10}"

# Check for auth token
if [ -z "$FEVER_B2B_TOKEN" ]; then
  echo "ERROR: FEVER_B2B_TOKEN environment variable not set"
  echo ""
  echo "To get your token:"
  echo "1. Login to https://partners.feverup.com"
  echo "2. Open browser DevTools > Network tab"
  echo "3. Find any API request to services.feverup.com"
  echo "4. Copy the Authorization header value (without 'B2bToken ' prefix)"
  echo ""
  echo "Then run:"
  echo "  export FEVER_B2B_TOKEN='your-token-here'"
  echo "  ./scripts/test-fever-reviews.sh"
  exit 1
fi

BASE_URL="https://services.feverup.com/b2b-partners/1.0"

echo "=== Fever Partners Reviews API ==="
echo "Partner ID: $PARTNER_ID"
echo "City ID: $CITY_ID"
echo "Place ID: $PLACE_ID"
echo ""

echo "=== Fetching Reviews ==="
curl -s "${BASE_URL}/partners/${PARTNER_ID}/reviews?items_per_page=${ITEMS_PER_PAGE}&page=${PAGE}&city_id=${CITY_ID}&question_type=general-review&place_id=${PLACE_ID}&order_by=answered_at&order_by_direction=desc" \
  -H "Accept: application/json" \
  -H "X-Client-Version: w.12.0.1" \
  -H "Authorization: B2bToken ${FEVER_B2B_TOKEN}" | jq '.'

echo ""
echo "=== Alternative: Fetch all reviews (no venue filter) ==="
echo "curl '${BASE_URL}/partners/${PARTNER_ID}/reviews?items_per_page=50&page=1&question_type=general-review&order_by=answered_at&order_by_direction=desc'"
