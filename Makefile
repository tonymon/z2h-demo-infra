# Local helpers. Every target first proves it is talking to the intended account.
# The default AWS profile is never used: PROFILE is always passed explicitly.
# Put machine-specific values in local.mk (gitignored):
#   EXPECTED = <12-digit account id>
#   BUDGET_EMAIL = you@example.com
-include local.mk

PROFILE    ?= personal
EXPECTED   ?=
DEMO       ?= bedrock-agent
REGION     ?= us-east-1
BUCKET     ?= z2h-demo-tfstate-$(EXPECTED)
MODEL      ?=

.PHONY: whoami
whoami:
	@test -n "$(EXPECTED)" || (echo "Set EXPECTED=<account id> in local.mk"; exit 1)
	@ACCT=$$(aws sts get-caller-identity --profile $(PROFILE) --query Account --output text); \
	if [ "$$ACCT" != "$(EXPECTED)" ]; then \
	  echo "REFUSING: profile '$(PROFILE)' is account $$ACCT, expected $(EXPECTED)"; exit 1; \
	fi; \
	echo "OK: profile '$(PROFILE)' -> account $$ACCT (intended account)"

.PHONY: bootstrap-plan bootstrap-apply
bootstrap-plan: whoami
	cd bootstrap && terraform init && terraform plan -var="expected_account_id=$(EXPECTED)" -var="budget_email=$(BUDGET_EMAIL)"

bootstrap-apply: whoami
	cd bootstrap && terraform init && terraform apply -var="expected_account_id=$(EXPECTED)" -var="budget_email=$(BUDGET_EMAIL)"

define TF_INIT
cd demos/$(DEMO) && terraform init -reconfigure \
  -backend-config="bucket=$(BUCKET)" \
  -backend-config="key=demos/$(DEMO)/terraform.tfstate" \
  -backend-config="region=$(REGION)" \
  -backend-config="use_lockfile=true"
endef

.PHONY: plan up down
plan: whoami
	@test -n "$(MODEL)" || (echo "Set MODEL=<model or inference-profile id>"; exit 1)
	$(TF_INIT)
	cd demos/$(DEMO) && terraform plan -var="aws_profile=$(PROFILE)" -var="expected_account_id=$(EXPECTED)" -var="foundation_model=$(MODEL)"

up: whoami
	@test -n "$(MODEL)" || (echo "Set MODEL=<model or inference-profile id>"; exit 1)
	$(TF_INIT)
	cd demos/$(DEMO) && terraform apply -var="aws_profile=$(PROFILE)" -var="expected_account_id=$(EXPECTED)" -var="foundation_model=$(MODEL)"

down: whoami
	$(TF_INIT)
	cd demos/$(DEMO) && terraform destroy -var="aws_profile=$(PROFILE)" -var="expected_account_id=$(EXPECTED)" -var="foundation_model=$(or $(MODEL),unused)"
