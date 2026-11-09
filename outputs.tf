output "organization_id" {
  value = aws_organizations_organization.this.id
}

output "root_id" {
  value = aws_organizations_organization.this.roots[0].id
}

output "ou_ids" {
  value = local.ou_ids
}

output "account_ids" {
  value = { for name, acct in aws_organizations_account.members : name => acct.id }
}

output "cloudtrail_bucket" {
  value = aws_s3_bucket.trail.id
}
