# DPAs / transfer paperwork the owner must complete

Tick when signed/accepted and file a copy. "SCCs" = EU Standard Contractual Clauses (+ UK Addendum);
for Saudi PDPL transfers keep the same documents as the contractual safeguard.

| Vendor | Role | Data | Paperwork | Where | Done |
|---|---|---|---|---|---|
| Google Firebase / Google Cloud | Processor | accounts, tasks, tokens (London) | Accept **Cloud Data Processing Addendum** (includes SCCs) | Firebase/GCP console → Settings → Data processing & security terms | ☐ |
| Cloudflare | Processor | voice audio/transcript in transit, task IDs | Cloudflare **Customer DPA** (SCCs) | dash.cloudflare.com → Account → Legal | ☐ |
| Groq | Processor | voice audio + transcript (US) | Groq DPA/SCCs; confirm zero-retention / no-training terms | Groq console / privacy@groq.com | ☐ |
| Google Gemini API | Processor (fallback) | voice audio + transcript | Gemini API terms: use the **paid** tier (free tier may train on data) + Cloud DPA | Google AI Studio / Cloud billing | ☐ |
| OpenAI | Not a direct vendor today | — | Only if a direct OpenAI call is added | — | n/a |
| Apple / Google Sign-In | Independent controllers | name, email | Developer-program terms; no DPA | — | ☐ review |
| GitHub (Pages) | Processor | IP addresses of visitors | GitHub **DPA** | GitHub org settings | ☐ |
| RevenueCat (when enabled) | Processor | purchase status | RevenueCat DPA | RevenueCat dashboard | ☐ |

Also: record processing activities (RoPA), complete a Transfer Impact Assessment for Groq/Gemini (US), decide whether an
EU/UK representative or a Saudi representative is needed, and register with SDAIA if required for your processing.
