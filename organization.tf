resource "aws_organizations_organization" "this" {
  feature_set          = "ALL"
  enabled_policy_types = ["SERVICE_CONTROL_POLICY"]

  aws_service_access_principals = [
    "cloudtrail.amazonaws.com",
    "config.amazonaws.com",
    "guardduty.amazonaws.com",
    "securityhub.amazonaws.com",
    "sso.amazonaws.com",
  ]
}

# --- Organizational units ------------------------------------------------

locals {
  top_level_ous = toset(["Security", "Infrastructure", "Workloads", "Sandbox"])
  workload_ous  = toset(["Prod", "NonProd"])
}

resource "aws_organizations_organizational_unit" "top" {
  for_each  = local.top_level_ous
  name      = each.key
  parent_id = aws_organizations_organization.this.roots[0].id
}

resource "aws_organizations_organizational_unit" "workloads" {
  for_each  = local.workload_ous
  name      = each.key
  parent_id = aws_organizations_organizational_unit.top["Workloads"].id
}

locals {
  ou_ids = {
    security       = aws_organizations_organizational_unit.top["Security"].id
    infrastructure = aws_organizations_organizational_unit.top["Infrastructure"].id
    prod           = aws_organizations_organizational_unit.workloads["Prod"].id
    nonprod        = aws_organizations_organizational_unit.workloads["NonProd"].id
    sandbox        = aws_organizations_organizational_unit.top["Sandbox"].id
  }
}

# --- Member accounts -----------------------------------------------------

resource "aws_organizations_account" "members" {
  for_each = var.member_accounts

  name              = each.key
  email             = each.value.email
  parent_id         = local.ou_ids[each.value.ou]
  role_name         = "OrganizationAccountAccessRole"
  close_on_deletion = false

  # role_name can only be set at creation time.
  lifecycle {
    ignore_changes = [role_name]
  }
}
