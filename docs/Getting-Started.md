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
2. Choose **Azure Resource Manager → Service principal (automatic)**
3. Scope to the subscription and resource group (`rg-devops-agents-prd`)
4. Name it **`Azure-Service-Connection`** (must match the pipeline variable)

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
