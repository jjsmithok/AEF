# Terraform outputs

output "organization" {
  description = "Organization details"
  value = {
    id          = data.aws_organization.org.id
    arn         = data.aws_organization.org.arn
    feature_set = data.aws_organization.org.feature_set
  }
}

output "organizational_units" {
  description = "Created Organizational Units"
  value = {
    security      = aws_organizations_organizational_unit.security.id
    logging       = aws_organizations_organizational_unit.logging.id
    monitoring    = aws_organizations_organizational_unit.monitoring.id
    control_tower = aws_organizations_organizational_unit.control_tower.id
    environments  = aws_organizations_organizational_unit.environments.id
    sandbox       = aws_organizations_organizational_unit.sandbox.id
    dev           = aws_organizations_organizational_unit.dev.id
    test          = aws_organizations_organizational_unit.test.id
    preprod       = aws_organizations_organizational_unit.preprod.id
    prod          = aws_organizations_organizational_unit.prod.id
  }
}

output "accounts" {
  description = "Created AWS Accounts"
  value = {
    security_tools  = aws_organizations_account.security_tools.id
    central_logging = aws_organizations_account.central_logging.id
    monitoring      = aws_organizations_account.monitoring.id
    control_tower   = aws_organizations_account.control_tower.id
    sandbox         = aws_organizations_account.sandbox.id
    dev             = aws_organizations_account.dev.id
    test            = aws_organizations_account.test.id
    preprod         = aws_organizations_account.preprod.id
    prod            = aws_organizations_account.prod.id
  }
}
