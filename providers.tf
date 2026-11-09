# Run this from the Organization management account.
provider "aws" {
  region = var.home_region

  default_tags {
    tags = var.tags
  }
}
