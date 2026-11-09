locals {
  # Services whose APIs are global or only available in us-east-1.
  global_service_actions = [
    "a4b:*", "budgets:*", "ce:*", "cloudfront:*", "cur:*", "globalaccelerator:*",
    "health:*", "iam:*", "organizations:*", "route53:*", "route53domains:*",
    "shield:*", "sts:*", "support:*", "trustedadvisor:*", "waf:*",
  ]

  scps = {
    deny-leave-org = {
      description = "Prevent member accounts from leaving the organization."
      policy = jsonencode({
        Version = "2012-10-17"
        Statement = [{
          Sid      = "DenyLeaveOrganization"
          Effect   = "Deny"
          Action   = ["organizations:LeaveOrganization"]
          Resource = "*"
        }]
      })
    }

    deny-root-user = {
      description = "Block all actions by the root user in member accounts."
      policy = jsonencode({
        Version = "2012-10-17"
        Statement = [{
          Sid      = "DenyRootUser"
          Effect   = "Deny"
          Action   = "*"
          Resource = "*"
          Condition = {
            StringLike = { "aws:PrincipalArn" = ["arn:aws:iam::*:root"] }
          }
        }]
      })
    }

    region-restriction = {
      description = "Deny use of regions outside the approved list."
      policy = jsonencode({
        Version = "2012-10-17"
        Statement = [{
          Sid       = "DenyUnapprovedRegions"
          Effect    = "Deny"
          NotAction = local.global_service_actions
          Resource  = "*"
          Condition = {
            StringNotEquals = { "aws:RequestedRegion" = var.allowed_regions }
          }
        }]
      })
    }

    protect-security-services = {
      description = "Stop member accounts from disabling logging and threat detection."
      policy = jsonencode({
        Version = "2012-10-17"
        Statement = [{
          Sid    = "DenyDisablingSecurityServices"
          Effect = "Deny"
          Action = [
            "cloudtrail:StopLogging",
            "cloudtrail:DeleteTrail",
            "config:StopConfigurationRecorder",
            "config:DeleteConfigurationRecorder",
            "guardduty:DeleteDetector",
            "guardduty:DisassociateFromMasterAccount",
            "securityhub:DisableSecurityHub",
          ]
          Resource = "*"
        }]
      })
    }
  }

  # Policy name -> target OU/root. Child OUs inherit from their parent.
  scp_attachments = {
    leave-org-root         = { policy = "deny-leave-org", target = aws_organizations_organization.this.roots[0].id }
    protect-security-root  = { policy = "protect-security-services", target = aws_organizations_organization.this.roots[0].id }
    region-workloads       = { policy = "region-restriction", target = aws_organizations_organizational_unit.top["Workloads"].id }
    region-sandbox         = { policy = "region-restriction", target = aws_organizations_organizational_unit.top["Sandbox"].id }
    no-root-user-workloads = { policy = "deny-root-user", target = aws_organizations_organizational_unit.top["Workloads"].id }
    no-root-user-sandbox   = { policy = "deny-root-user", target = aws_organizations_organizational_unit.top["Sandbox"].id }
  }
}

resource "aws_organizations_policy" "scp" {
  for_each = local.scps

  name        = each.key
  description = each.value.description
  type        = "SERVICE_CONTROL_POLICY"
  content     = each.value.policy
}

resource "aws_organizations_policy_attachment" "scp" {
  for_each = local.scp_attachments

  policy_id = aws_organizations_policy.scp[each.value.policy].id
  target_id = each.value.target
}
