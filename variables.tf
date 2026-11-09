variable "home_region" {
  description = "Primary region for the organization trail bucket and security services."
  type        = string
  default     = "ca-central-1"
}

variable "allowed_regions" {
  description = "Regions workload accounts may use. Enforced by the region-restriction SCP."
  type        = list(string)
  default     = ["ca-central-1", "us-east-1"]
}

variable "trail_name" {
  description = "Name of the organization-wide CloudTrail."
  type        = string
  default     = "org-trail"
}

variable "trail_bucket_prefix" {
  description = "Prefix for the CloudTrail log bucket. The management account ID is appended."
  type        = string
  default     = "example-org-cloudtrail"
}

variable "member_accounts" {
  description = "Member accounts to create. Key is the account name; ou is one of: security, infrastructure, prod, nonprod, sandbox."
  type = map(object({
    email = string
    ou    = string
  }))

  validation {
    condition     = alltrue([for a in values(var.member_accounts) : contains(["security", "infrastructure", "prod", "nonprod", "sandbox"], a.ou)])
    error_message = "Each account's ou must be one of: security, infrastructure, prod, nonprod, sandbox."
  }

  validation {
    condition     = contains(keys(var.member_accounts), "security")
    error_message = "A member account named \"security\" is required (delegated admin for GuardDuty and Security Hub)."
  }
}

variable "tags" {
  description = "Default tags applied to all resources."
  type        = map(string)
  default = {
    ManagedBy = "terraform"
    Project   = "aws-landing-zone"
  }
}
