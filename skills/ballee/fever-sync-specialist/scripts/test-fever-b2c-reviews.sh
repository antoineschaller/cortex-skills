#!/bin/bash
# Test Fever Reviews API - Research Findings
#
# ============================================================================
# FEVER API ARCHITECTURE DISCOVERED
# ============================================================================
#
# API Base URLs (from partners.feverup.com bundle):
#   - apiB2CBaseUrl:      https://services.feverup.com         (B2C consumer API)
#   - apiBaseUrl:         https://services.feverup.com/b2b     (B2B legacy API)
#   - apiB2cSiteBaseUrl:  https://services.feverup.com/b2c_site
#   - apiGWBaseUrl:       https://services.feverup.com/b2b-partners  (B2B Partners gateway)
#   - apiIamBaseUrl:      https://services.feverup.com/b2b-iam (Identity/Auth)
#
# KEY FINDING: Individual reviews are NOT exposed via public API!
# Reviews are server-side rendered (SSR) directly into HTML using Astro framework.
# This is likely for SEO purposes - reviews appear in HTML for search engine indexing.
#
# ============================================================================
# WHAT'S AVAILABLE VIA API
# ============================================================================
#
# 1. Plan Rating Aggregate (PUBLIC - no auth required):
#    GET /api/4.4/plans/{plan_id}/
#    Returns: rating.average, rating.num_ratings, rating.is_hidden
#
# 2. Survey Replies (B2B Partners - requires auth):
#    GET /b2b-partners/1.0/partners/{partner_id}/survey-replies
#
# 3. Plans with Analytics (B2B Partners - requires auth):
#    GET /b2b-partners/1.0/partners/{partner_id}/plans-with-analytics
#
# ============================================================================

# Use a plan ID with reviews (The Jury Experience - NYC)
PLAN_ID=266311

echo "=== 1. Get Plan Rating Data (PUBLIC API) ==="
echo "Endpoint: GET /api/4.4/plans/{plan_id}/"
curl -s "https://feverup.com/api/4.4/plans/$PLAN_ID/" \
  -H "Accept: application/json" \
  -H "X-Client-Version: w.12.0.1" | jq '{
    id,
    name,
    rating: .rating,
    should_display_featured_review_answers,
    presentation_settings: {
      reviews_from_plan_id: .presentation_settings.reviews_from_plan_id,
      show_reviews_from_main_plan_info: .presentation_settings.show_reviews_from_main_plan_info,
      hide_rating: .presentation_settings.hide_rating
    }
  }' 2>/dev/null

echo ""
echo "=== 2. Scrape Reviews from SSR HTML (workaround) ==="
echo "Reviews are rendered server-side into HTML:"
curl -s "https://feverup.com/m/$PLAN_ID" 2>/dev/null | \
  grep -oE 'class="name[^"]*">[^<]+|class="date[^"]*">[^<]+|class="reason[^"]*">[^<]+' | \
  sed 's/class="[^"]*">//g' | \
  paste - - - 2>/dev/null | head -10

echo ""
echo "=== 3. Test if /reviews endpoint exists (it doesn't) ==="
response=$(curl -s -o /dev/null -w "%{http_code}" "https://feverup.com/api/4.4/plans/$PLAN_ID/reviews")
echo "GET /api/4.4/plans/$PLAN_ID/reviews -> HTTP $response"

echo ""
echo "============================================================================"
echo "SUMMARY: Fever Reviews API Research"
echo "============================================================================"
echo ""
echo "✅ AVAILABLE:"
echo "   - Rating aggregates (average, count) via /api/4.4/plans/{id}/"
echo "   - Review content via HTML scraping of /m/{plan_id}"
echo ""
echo "❌ NOT AVAILABLE (no public API):"
echo "   - Individual review text, dates, ratings via API"
echo "   - Reviewer names via API"
echo "   - Review pagination/filtering via API"
echo ""
echo "🔐 REQUIRES B2B AUTH (partners.feverup.com):"
echo "   - /b2b-partners/1.0/partners/{id}/survey-replies"
echo "   - /b2b-partners/1.0/partners/{id}/plans-with-analytics"
echo ""
echo "📝 For Ballee Integration:"
echo "   - Store rating aggregates from plan sync"
echo "   - Consider scraping reviews from HTML if needed"
echo "   - Explore authenticated B2B endpoints for partner data"
