using './main.bicep'

// ── Dev Center ──────────────────────────────────────────────────────────────
param devCenterName        = 'dc-devops-prd'
param devCenterProjectName = 'dc-project-devops-prd'

// ── Pool ─────────────────────────────────────────────────────────────────────
param poolName             = 'mdp-windows-prd'
param organizationUrl      = 'https://dev.azure.com/YOUR-ORG'
param projects             = []          // empty = all projects
param maximumConcurrency   = 4
param vmSize               = 'Standard_D4s_v5'
param osType               = 'Windows'
param agentLifecycle       = 'Stateless'

// ── Shared ───────────────────────────────────────────────────────────────────
param environment          = 'prd'
