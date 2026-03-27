# Move Pay — Infrastructure as Code

## Repo structure

```
movepay-infra/
├── main.bicep                    ← entry point, orchestrates all modules
├── modules/
│   ├── network.bicep             ← VNET, subnets, NSGs, Private DNS zones
│   ├── keyvault.bicep            ← Key Vault + RBAC assignments
│   ├── storage.bicep             ← Storage account + blob container + private endpoint
│   ├── sql.bicep                 ← SQL Server + database + private endpoint
│   ├── functionapp.bicep         ← App Service Plan + Function App + Managed Identity
│   ├── logicapp.bicep            ← Logic App + blob trigger workflow
│   ├── monitoring.bicep          ← Application Insights + Log Analytics + alerts
│   └── roles.bicep               ← All RBAC role assignments
├── parameters/
│   ├── dev.bicepparam            ← Dev environment values
│   ├── test.bicepparam           ← Test environment values
│   └── prod.bicepparam           ← Production environment values
├── .devops/
│   └── pipeline.yml              ← Azure DevOps CI/CD pipeline
└── payment-func-app/             ← Your Python function code lives here
    ├── function_app.py
    └── requirements.txt
```

---

## Part 1: Connect GitHub to Azure DevOps

### Step 1 — Create an Azure DevOps project

1. Go to https://dev.azure.com and sign in with your work account
2. Create a new organisation if you don't have one (e.g. `BSEMIA-Prod`)
3. Create a new project: `MovePay`
4. Set visibility to **Private**

### Step 2 — Create a Service Connection (DevOps → Azure)

This gives the pipeline permission to deploy to your Azure subscription.

1. In Azure DevOps, go to **Project Settings** → **Service connections** → **New service connection**
2. Choose **Azure Resource Manager**
3. Choose **Service principal (automatic)** — DevOps creates the SPN for you
4. Select your subscription: `Azure subscription 1 (fdddaca3-...)`
5. Leave resource group **blank** — you want subscription-level access so it can deploy to any resource group
6. Name it exactly: `movepay-azure-connection`
7. Tick **Grant access permission to all pipelines**
8. Save

> After saving, note the Service Principal App ID shown — you'll need its Object ID for the Bicep role assignments.
> Find it with: `az ad sp list --display-name "movepay-azure-connection" --query "[].id" -o tsv`

### Step 3 — Create secret variable group (DevOps Library)

This stores the SQL passwords without putting them in your git repo.

1. Go to **Pipelines** → **Library** → **+ Variable group**
2. Name it: `movepay-secrets`
3. Add these variables (click the lock icon to make each one secret):
   - `SQL_ADMIN_PASSWORD_DEV` — a strong password for dev SQL
   - `SQL_ADMIN_PASSWORD_TEST` — a different strong password for test SQL
   - `SQL_ADMIN_PASSWORD_PROD` — a different strong password for prod SQL
4. Save

### Step 4 — Connect GitHub as your code source

1. In Azure DevOps go to **Pipelines** → **New pipeline**
2. Where is your code? → **GitHub**
3. First time only: click **Authorize Azure Pipelines** — this installs the Azure Pipelines GitHub App on your GitHub account
4. Select your repository (e.g. `your-org/movepay`)
5. Azure DevOps will look for a pipeline file. Choose **Existing Azure Pipelines YAML file**
6. Branch: `main`, Path: `/.devops/pipeline.yml`
7. Click **Continue** then **Save** (don't run yet)

> What just happened: The Azure Pipelines GitHub App is now installed on your GitHub repo. Every push to `main` will trigger this pipeline. Pull requests will show pipeline status checks in GitHub.

### Step 5 — Create Environments with approval gates

1. Go to **Pipelines** → **Environments** → **New environment**
2. Create three environments:
   - `movepay-dev` — no approvals
   - `movepay-test` — add approval: Approvers = your QA lead
   - `movepay-prod` — add approval: Approvers = project lead, minimum approvers = 1

For each environment after creation:
- Click the environment → **...** (three dots) → **Approvals and checks**
- Add **Approvals** → select the approver(s) → Save

### Step 6 — Fill in the parameter files

Open `parameters/dev.bicepparam`, `test.bicepparam`, and `prod.bicepparam`.

Replace the empty `''` values with your actual Entra ID object IDs:

```bash
# Find your developer group object ID
az ad group show --group "MovePay-Developers" --query id -o tsv

# Find your DevOps SPN object ID (from Step 2 above)
az ad sp list --display-name "movepay-azure-connection" --query "[].id" -o tsv

# Find your own user object ID (useful for testing)
az ad signed-in-user show --query id -o tsv
```

If you don't have Entra ID groups yet, create them:
```bash
az ad group create --display-name "MovePay-Developers" --mail-nickname "movepay-devs"
az ad group create --display-name "MovePay-QA" --mail-nickname "movepay-qa"
az ad group create --display-name "MovePay-Business" --mail-nickname "movepay-business"

# Add yourself to the developer group
az ad group member add \
  --group "MovePay-Developers" \
  --member-id $(az ad signed-in-user show --query id -o tsv)
```

### Step 7 — Create the resource groups (one-time, before first pipeline run)

```bash
az login
az account set --subscription 'fdddaca3-a991-4301-8149-389bb3aaf4f9'

az group create --name rg-movepay-dev  --location westeurope
az group create --name rg-movepay-test --location westeurope
az group create --name rg-movepay-prod --location westeurope
```

Then grant the DevOps SPN Contributor on each resource group:
```bash
DEVOPS_SPN_ID=$(az ad sp list --display-name "movepay-azure-connection" --query "[].id" -o tsv)

for RG in rg-movepay-dev rg-movepay-test rg-movepay-prod; do
  az role assignment create \
    --role Contributor \
    --assignee-object-id $DEVOPS_SPN_ID \
    --assignee-principal-type ServicePrincipal \
    --scope /subscriptions/fdddaca3-a991-4301-8149-389bb3aaf4f9/resourceGroups/$RG
done
```

### Step 8 — Run the pipeline

1. Push your changes to GitHub (or just trigger manually in DevOps)
2. The pipeline will:
   - Lint and validate all Bicep templates
   - Build the Python function app
   - Deploy everything to **dev** automatically
   - Wait for your QA approval before deploying to **test**
   - Wait for your lead's approval before deploying to **prod**

---

## Part 2: After first deployment

### Grant SQL access to Managed Identities

After the Function App and Logic App are created, their Managed Identities need database access. Connect to SQL as admin and run:

```sql
-- Run in SQL Server Management Studio or Azure Data Studio
-- Connect to: sql-movepay-dev.database.windows.net (or test/prod)

-- Grant Function App access
CREATE USER [func-movepay-dev] FROM EXTERNAL PROVIDER;
ALTER ROLE db_datareader ADD MEMBER [func-movepay-dev];
ALTER ROLE db_datawriter ADD MEMBER [func-movepay-dev];

-- Grant Logic App access (if it needs direct SQL access)
CREATE USER [logic-movepay-dev] FROM EXTERNAL PROVIDER;
ALTER ROLE db_datareader ADD MEMBER [logic-movepay-dev];
```

Repeat for test and prod (changing the resource names accordingly).

### Verify the Logic App trigger

1. Upload a test file to the `payment-storage-logic` container in the dev Storage Account
2. Wait up to 1 minute (polling interval)
3. Go to the Logic App in the Portal → Overview → Runs history
4. You should see a run with Status: **Succeeded** and Fired: **True**

---

## Manual deployment (without the pipeline)

For quick testing during development:

```bash
az deployment group create \
  --resource-group rg-movepay-dev \
  --template-file main.bicep \
  --parameters parameters/dev.bicepparam \
  --parameters sqlAdminPassword='YourDevPassword123!'
```

---

## Updating an existing environment

Bicep is **idempotent** — running it again on existing resources updates them to match the template without deleting them. Just push your change to GitHub and the pipeline re-runs automatically.

If you make a change directly in the Portal (emergency fix), remember to update the Bicep template afterwards so the next deployment doesn't revert your change.
