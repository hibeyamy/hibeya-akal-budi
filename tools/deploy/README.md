# Learner Web Deployment

Canonical frontend host: Vercel.

Repository root must remain the Vercel project root because learner-web depends on pnpm workspace packages.

## Required Vercel Production environment variables

- VITE_SUPABASE_URL
- VITE_SUPABASE_PUBLISHABLE_KEY
- VITE_HIBEYA_ADAPTIVE_ENABLED
- VITE_HIBEYA_ADAPTIVE_ROLLOUT_PERCENT

Allowed adaptive production states are deliberately restricted:

- controlled observation: true / 1
- kill switch: false / 0

The Vercel build fails for any other rollout percentage.

Build:
pnpm --filter learner-web build

Output:
apps/learner-web/dist

Do not commit secret or environment-specific credentials into vercel.json.
The Supabase publishable key is client-safe by design but remains deployment configuration rather than hosting configuration.
