# z2h-demo-infra

Ephemeral, auditable AWS demos for [Zero to Hero AI](https://zero2heroai.com).
Every demo is deployed from a pull request, shown, and destroyed. Nothing
stays running, no long-lived AWS keys exist, and every run leaves a cost receipt.

This is the proof layer behind the content series: *deploy, demo, destroy,
show the bill.*

## What is in the box

| Path | Purpose |
|---|---|
| `bootstrap/` | One-time, applied by hand: S3 state bucket, GitHub OIDC trust, a read-only **plan** role, a scoped **apply** role, and a monthly budget alarm. |
| `modules/bedrock-agent/` | A Bedrock agent, its least-privilege service role and a `live` alias. |
| `demos/bedrock-agent/` | Root stack for demo 1. Remote state in S3 with native locking. |
| `.github/workflows/plan.yml` | On PRs: format check, Checkov scan, validate, plan with a **read-only** role. |
| `.github/workflows/apply.yml` | Manual `demo-up`, behind the `demo` environment's required reviewer. |
| `.github/workflows/destroy.yml` | Manual `demo-down`, same gate. |
| `.github/workflows/reaper.yml` | Nightly destroy of every demo stack (`demo-reaper` environment, no approver). |

## Zero-trust properties (and where each one lives)

- **No stored credentials.** GitHub mints a short-lived OIDC token per run; AWS
  trusts only this repo, and only specific contexts (`pull_request`,
  `environment:demo`, `environment:demo-reaper`). See `bootstrap/main.tf`.
- **Separation of duties.** Pull requests can only *read* (plan role).
  Changes require a human approval on the `demo` environment.
- **Blast-radius limits.** The apply role can only touch Bedrock agents and
  IAM roles named `z2h-demo-*`, and can only pass them to Bedrock.
- **Wrong-account protection.** The provider sets `allowed_account_ids`; the
  Makefile verifies the profile's account before every command.
- **Nothing lingers.** Nightly reaper plus a monthly budget alarm.
- **Policy as code.** Checkov runs on every PR (soft-fail at first; flip to
  hard-fail once findings are triaged).

## Account safety

Never rely on the default AWS profile. Always pass `--profile personal`; the
Makefile does it for you and refuses to run if the profile resolves to any
account other than the one in your gitignored `local.mk`
(`EXPECTED = <12-digit account id>`). The Terraform providers enforce the same
check with `allowed_account_ids`.

## First-time setup (once)

1. Create `local.mk` (gitignored) with `EXPECTED = <account id>` and
   `BUDGET_EMAIL = you@example.com`, then run `make whoami`. It must print `OK`.
2. Create the GitHub repo `tonymon/z2h-demo-infra` and push this folder.
3. `make bootstrap-apply` — review the plan, then
   type `yes`. Note the three outputs.
4. In the GitHub repo settings:
   - Secrets: `AWS_ROLE_PLAN_ARN`, `AWS_ROLE_APPLY_ARN`, `TF_STATE_BUCKET`,
     `AWS_ACCOUNT_ID` (secrets are masked in public logs).
   - Variable: `FOUNDATION_MODEL` (a model or inference-profile ID you have
     access to; check Bedrock console > Model access).
   - Environments: `demo` (add yourself as **required reviewer**) and
     `demo-reaper` (no reviewer).
5. In AWS, enable access to your chosen model in us-east-1.

## Recording a demo (the cost-receipt format)

1. Open a PR touching `demos/` and show the plan and the Checkov output.
2. Merge, run **demo-up**, approve it.
3. Demo the agent for 60 seconds.
4. Run **demo-down**.
5. End on Cost Explorer filtered by tag `Project = z2h-demo-infra` (cost
   allocation tags must be activated in Billing; data lags up to ~24 hours, so
   show the previous day's receipt or the budget page if needed).

## Local run (optional)

```bash
make whoami
make plan MODEL=<model-or-inference-profile-id>
make up   MODEL=<model-or-inference-profile-id>
make down
```

## Not yet verified / next

- First real apply has not been run. The IAM policy for the apply role should be
  tightened with IAM Access Analyzer after the first run.
- Connect demo module (chat-only first; check current Connect pricing before
  adding phone numbers or voice).
- A dedicated AWS account for demos (via AWS Organizations) would be a better
  boundary than sharing the account that hosts the website.
- Pin GitHub Actions to commit SHAs once the workflows settle.
- Keep this repo public-safe: no account IDs, no real client data, nothing tied
  to any employer.
