# Lead Generation Framework

Generic lead generation patterns for any business model.

## Collection Overview

Framework skills providing reusable patterns for lead generation, scoring, and follow-up. These are **NOT project-specific** - they serve as templates for creating business-specific implementations.

## Skills

### lead-scoring-system
**Purpose:** Generic lead scoring and qualification patterns (1-100 scale)

**Use Cases:**
- Building lead qualification systems
- Tracking prospect engagement through funnel
- Prioritizing sales follow-ups
- Measuring conversion funnel effectiveness
- Automating lead routing based on score

**Key Features:**
- Progressive scoring model (awareness → conversion)
- Score decay for stale leads
- Funnel stage definitions
- Lead routing patterns
- Conversion analytics

**Scoring Model:**
```
 0-20  | Cold Lead (awareness)
21-40  | Warm Lead (interest)
41-60  | Hot Lead (consideration)
61-80  | Very Hot Lead (intent)
81-100 | Conversion (transaction)
```

### sla-tracking
**Purpose:** Generic SLA tracking for lead response times

**Use Cases:**
- Monitoring response performance
- Ensuring timely follow-ups
- Building accountability systems
- Analyzing response time impact
- Automating escalations

**Key Features:**
- Tiered SLA system (urgent/high/normal/low)
- Automatic breach detection
- Escalation workflows
- Team performance analytics
- Business hours support

**SLA Tiers:**
```
URGENT:  <1 hour   | Hot leads (80+ score)
HIGH:    <4 hours  | Warm leads (60-79 score)
NORMAL:  <24 hours | Medium leads (40-59 score)
LOW:     <48 hours | Cold leads (20-39 score)
```

## How to Use Framework Skills

### 1. Create Project-Specific Implementation

```bash
# Example: MyArmy lead generation
mkdir -p myarmy-skills/lead-scoring-myarmy
cd myarmy-skills/lead-scoring-myarmy
```

### 2. Reference Framework in skill.config.json

```json
{
  "skill": "lead-scoring-myarmy",
  "version": "1.0.0",
  "extends": "lead-generation-framework/lead-scoring-system",
  "dependencies": {
    "packages": [
      { "name": "@supabase/supabase-js", "version": "latest" }
    ],
    "env_vars": {
      "SUPABASE_URL": {
        "required": true,
        "description": "Supabase project URL"
      },
      "SUPABASE_ANON_KEY": {
        "required": true,
        "description": "Supabase anonymous key"
      }
    }
  },
  "configuration": {
    "funnel_stages": {
      "awareness": { "min": 0, "max": 20 },
      "interest": { "min": 21, "max": 40 },
      "consideration": { "min": 41, "max": 60 },
      "intent": { "min": 61, "max": 80 },
      "conversion": { "min": 81, "max": 100 }
    },
    "scoring_events": {
      "page_view": 5,
      "product_view": 15,
      "inquiry_started": 40,
      "whatsapp_contact": 85,
      "purchase": 100
    },
    "sla_tiers": {
      "urgent": { "response_minutes": 60, "escalation_minutes": 90 },
      "high": { "response_minutes": 240, "escalation_minutes": 300 },
      "normal": { "response_minutes": 1440, "escalation_minutes": 1560 }
    }
  },
  "tags": ["lead-generation", "swiss-market", "b2b"]
}
```

### 3. Create Implementation Documentation

```markdown
---
name: lead-scoring-myarmy
extends: lead-generation-framework/lead-scoring-system
---

# MyArmy Lead Scoring

Extends `lead-generation-framework/lead-scoring-system` with Swiss military market specifics.

## MyArmy Funnel

1. **Awareness** (0-20): Landing page visit, social media
2. **Interest** (21-40): Product page view, custom badge info
3. **Consideration** (41-60): Contact form started, pricing viewed
4. **Intent** (61-80): WhatsApp contact initiated
5. **Conversion** (81-100): Quote submitted, order placed

## Custom Events

- `military_product_view`: +15 (funktionsabzeichen, truppenabzeichen)
- `custom_design_inquiry`: +50 (custom badge design requested)
- `whatsapp_badge_inquiry`: +85 (WhatsApp contact for badge order)

## Swiss Market Context

- Business hours: 9am-5pm CET
- Response expectations: 1h urgent, 4h high, 24h normal
- Languages: German (primary), French, Italian
```

## Integration Patterns

### Lead Scoring + SLA Tracking

```typescript
// When lead score changes, update SLA tier
async function onLeadScoreUpdate(lead: Lead) {
  const newTier = determineSLATier(lead.score);

  if (lead.sla_tier !== newTier) {
    // Update SLA tier
    await updateSLATier(lead.id, newTier);

    // Notify if escalation needed
    if (newTier === 'urgent') {
      await notifySalesTeam(lead);
    }
  }
}

// When SLA is created, track first response
async function onInquirySubmitted(leadId: string, leadScore: number) {
  // Create lead scoring record
  await trackEvent(leadId, 'inquiry_submitted', 40);

  // Create SLA record
  const tier = determineSLATier(leadScore + 40);
  await createSLA(leadId, tier);
}
```

### Automated Follow-up System

```typescript
// Cron job: Check for leads needing follow-up
export async function checkFollowUps() {
  // Get leads with pending SLAs
  const pendingSLAs = await getPendingSLAs();

  for (const sla of pendingSLAs) {
    const lead = await getLead(sla.lead_id);

    // Check if approaching deadline
    const timeRemaining = sla.deadline - Date.now();
    if (timeRemaining < 15 * 60 * 1000) { // 15 minutes
      await sendReminder(sla.assignee, lead);
    }

    // Check for breach
    if (timeRemaining < 0) {
      await handleBreach(sla, lead);
    }
  }
}
```

## Database Requirements

Both framework skills require:

```sql
-- Leads table (from lead-scoring-system)
CREATE TABLE leads (
  id UUID PRIMARY KEY,
  email TEXT UNIQUE NOT NULL,
  score INTEGER DEFAULT 0,
  stage TEXT DEFAULT 'cold',
  source TEXT,
  last_activity TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- SLA records (from sla-tracking)
CREATE TABLE sla_records (
  id UUID PRIMARY KEY,
  lead_id UUID REFERENCES leads(id),
  tier TEXT NOT NULL,
  status TEXT DEFAULT 'pending',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  deadline TIMESTAMP WITH TIME ZONE NOT NULL,
  first_response_at TIMESTAMP WITH TIME ZONE,
  response_time_minutes INTEGER
);

-- Scoring events log
CREATE TABLE lead_scoring_events (
  id UUID PRIMARY KEY,
  lead_id UUID REFERENCES leads(id),
  event_name TEXT NOT NULL,
  score_delta INTEGER NOT NULL,
  timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

## Dependencies

Both framework skills use:
- **@supabase/supabase-js** - Database and auth
- **Vercel Cron** or **Supabase Edge Functions** - Automated checks

Install per-project:
```bash
npm install @supabase/supabase-js
```

## Benefits of Framework Pattern

### ✅ Flexibility
- Customize scoring events per business
- Adjust SLA tiers per market
- Add business-specific logic

### ✅ Best Practices
- Proven lead scoring models
- Industry-standard SLA patterns
- Scalable architectures

### ✅ Consistency
- Same patterns across products
- Unified reporting metrics
- Easier team training

## Example Implementations

### Real-World Examples
- `myarmy-skills/lead-scoring-myarmy` - Swiss military B2B lead funnel
- `myarmy-skills/sla-tracking-myarmy` - 1h/4h/24h/48h response tiers

### Your Implementation Here!
Follow the pattern above to create your own implementations.

## Testing

```typescript
// Test lead scoring progression
describe('Lead Scoring Integration', () => {
  it('should create SLA when lead reaches hot stage', async () => {
    const lead = await createLead('test@example.com');

    // Progress through funnel
    await trackEvent(lead.id, 'page_view', 5);      // Score: 5
    await trackEvent(lead.id, 'content_view', 15);  // Score: 20
    await trackEvent(lead.id, 'inquiry_started', 40); // Score: 60 (HOT)

    // Check SLA created
    const sla = await getSLAForLead(lead.id);
    expect(sla).toBeDefined();
    expect(sla.tier).toBe('high'); // Score 60-79
    expect(sla.status).toBe('pending');
  });
});
```

## Support

- **Issues**: https://github.com/your-org/cortex-skills
- **Documentation**: See individual skill README files
- **Examples**: Check myarmy-skills implementations
