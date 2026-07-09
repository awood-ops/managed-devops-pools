# Getting Started

## Prerequisites

| Requirement | Notes |
|---|---|
| Azure subscription | Contributor on the target resource group |
| Azure DevOps organisation | Project Collection Administrator or pool admin rights |
| Azure CLI | `az bicep restore` requires az CLI 2.47+ |
| `Microsoft.DevCenter` resource provider | Register once per subscription |
| `Microsoft.DevOpsInfrastructure` resource provider | Register once per subscription |

### Register resource providers

```bash
az provider register --namespace Microsoft.DevCenter --wait
az provider register --namespace Microsoft.DevOpsInfrastructure --wait
```

### Check registration status

```bash
az provider show -n Microsoft.DevCenter --query registrationState
az provider show -n Microsoft.DevOpsInfrastructure --query registrationState
```

Both should return `"Registered"` before deploying.

## Azure DevOps service connection

The pipelines use a service connection named `Azure-Service-Connection`. Create it in your Azure DevOps project:

1. **Project Settings → Service connections → New service connection**
2. Choose **Azure Resource Manager → Workload identity federation (automatic)** — prefer this over the classic secret-based "Service principal (automatic)" option; it avoids a rotatable secret entirely
3. Scope to the subscription and resource group (`rg-devops-agents-prd`)
4. Name it **`Azure-Service-Connection`** (must match the pipeline variable)

### Permissions the workload identity needs

Whichever identity backs `Azure-Service-Connection` (or the GitHub OIDC app used by the e2e workflow) needs **two separate sets of permissions** — Azure RBAC and Azure DevOps permissions are independent systems, and both are required:

| # | Permission | Scope | Why |
|---|---|---|---|
| 1 | `Contributor` (Azure RBAC) | Resource group (`rg-devops-agents-{env}`) | Creates/updates the Dev Center, Dev Center Project and Managed DevOps Pool resources deployed by `bicep/main.bicep` |
| 2 | `Contributor` (Azure RBAC) | Subscription | **e2e/test identity only** — `tests/e2e/defaults/main.test.bicep` deploys with `az deployment sub create` and creates/deletes its own resource group per run, so RG-scoped access isn't enough |
| 3 | Resource provider registration | Subscription | `Microsoft.DevCenter` and `Microsoft.DevOpsInfrastructure` must be `Registered` before the first deployment — this is a subscription-level operation, so it needs to be done once by an identity with broader rights (Owner, or Contributor at subscription scope) even if the ongoing deploy identity is scoped down to the resource group afterwards |
| 4 | `DevOps Infrastructure Pool Administrators` (Azure DevOps org permission) | Azure DevOps organisation | Lets the deployed pool be linked to and manage agents within the ADO organisation (see "Register the Azure DevOps organisation with the pool" below). This is an ADO-side group, unrelated to Azure RBAC |

Production/dev deploys only need #1 (plus #3 once, at bootstrap time). The e2e identity used by `.github/workflows/mdp.module.yml` additionally needs #2, since it deploys and tears down its own resource groups.

Automate all of this with:

```powershell
./scripts/Grant-WorkloadIdentityAccess.ps1 `
    -SubscriptionId <sub-id> `
    -ServicePrincipalObjectId <sp-object-id> `
    -ServicePrincipalAppId <sp-app-id> `
    -OrganizationUrl https://dev.azure.com/YOUR-ORG
```

Run with `-WhatIf` first to preview. See the script's comment-based help (`Get-Help ./scripts/Grant-WorkloadIdentityAccess.ps1 -Full`) for the e2e-identity variant (`-IncludeSubscriptionScope -SkipAdoGroupMembership`, since the e2e GitHub OIDC app is typically separate from the ADO service connection's identity). Run it with an account that itself has Owner (or Contributor + User Access Administrator) on the subscription and organisation-level Azure DevOps permissions — the granting identity always needs more rights than the identity it's granting to.

## Register the Azure DevOps organisation with the pool

After the Dev Center and pool are deployed, the pool needs to be linked to your Azure DevOps organisation:

1. In the Azure Portal, open the Managed DevOps Pool resource
2. Select **Settings → DevOps organizations**
3. Add your organisation URL (e.g. `https://dev.azure.com/myorg`)
4. Azure will prompt you to authorise via OAuth — sign in with an account that has organisation-level permissions

## Use the pool in a pipeline

Reference the pool by name in your pipeline YAML:

```yaml
pool:
  name: mdp-windows-prd   # must match the poolName parameter
```

## Parameters reference

See [bicep/main.bicepparam](../bicep/main.bicepparam) for all configurable values. Key parameters:

| Parameter | Default | Notes |
|---|---|---|
| `organizationUrl` | — | **Required.** Your ADO org URL |
| `maximumConcurrency` | 4 | Max parallel agents; affects cost |
| `vmSize` | `Standard_D4s_v5` | 4 vCPU, 16 GB RAM; adjust to workload |
| `osType` | `Windows` | `Windows` or `Linux` |
| `agentLifecycle` | `Stateless` | `Stateless` = fresh VM per job; `Stateful` = reuse between jobs |
| `projects` | `[]` | Scope to specific ADO projects, or leave empty for all |

## Costs

Managed DevOps Pools charges for:
- VM compute time while agents are running (no charge when idle)
- OS disk storage (Standard HDD by default)
- Dev Center (no additional charge for the service itself)

Use `Stateless` agents unless your jobs have significant startup overhead — stateless gives you a clean environment every time at no extra cost.
