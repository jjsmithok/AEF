# Service Control Policies (SCPs) for AWS Organization
# Apply these to OUs for security enforcement

# =====================================================
# DENY ROOT LOGIN - Apply to All OUs
# =====================================================

resource "aws_organizations_policy" "deny_root_login" {
  name        = "DenyRootLogin"
  description = "Prevents any usage of root account"
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyRootLogin"
        Effect = "Deny"
        Action = [
          "*"
        ]
        Resource = [
          "*"
        ]
        Condition = {
          StringLike = {
            "aws:PrincipalARN" = ["arn:aws:iam::*:root"]
          }
        }
      }
    ]
  })
}

# =====================================================
# DENY HUMAN CONSOLE ACCESS - Apply to Prod OU Only
# =====================================================

resource "aws_organizations_policy" "deny_human_console_prod" {
  name        = "DenyHumanConsoleProd"
  description = "Prevents human console access to Production except via BreakGlass"
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyHumanConsole"
        Effect = "Deny"
        Action = [
          "aws-portal:*Console*",
          "signin:*"
        ]
        Resource = [
          "*"
        ]
        Condition = {
          ArnNotLike = {
            "aws:PrincipalARN" = ["arn:aws:iam::*:role/BreakGlassRole"]
          }
        }
      }
    ]
  })
}

# =====================================================
# SANDBOX AUTO CLEANUP - Apply to Sandbox OU Only
# =====================================================

resource "aws_organizations_policy" "sandbox_auto_cleanup" {
  name        = "SandboxAutoCleanup"
  description = "Restricts resource creation in Sandbox after 24h"
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AutoDeleteResources"
        Effect = "Deny"
        Action = [
          "ec2:RunInstances",
          "rds:CreateDBInstance",
          "s3:CreateBucket",
          "lambda:CreateFunction"
        ]
        Resource = [
          "*"
        ]
        Condition = {
          DateGreaterThan = {
            "aws:CurrentTime" = "2026-02-27T00:00:00Z"
          }
        }
      }
    ]
  })
}

# =====================================================
# ATTACH POLICIES TO OUs
# =====================================================

# Deny Root Login - Attach to Root (applies to all)
resource "aws_organizations_policy_attachment" "deny_root_to_root" {
  policy_id = aws_organizations_policy.deny_root_login.id
  target_id = data.aws_organizations_roots.root.roots[0].id
}

# Deny Human Console - Attach to Prod (will need to update target_id after creating Prod account)
# resource "aws_organizations_policy_attachment" "deny_console_to_prod" {
#   policy_id  = aws_organizations_policy.deny_human_console_prod.id
#   target_id  = aws_organizations_account.prod.id  # Uncomment after running terraform
# }

# Sandbox Auto Cleanup - Attach to Sandbox
# resource "aws_organizations_policy_attachment" "sandbox_cleanup" {
#   policy_id  = aws_organizations_policy.sandbox_auto_cleanup.id
#   target_id  = aws_organizations_account.sandbox.id  # Uncomment after running terraform
# }

output "scp_policy_ids" {
  value = {
    deny_root_login      = aws_organizations_policy.deny_root_login.id
    deny_human_console   = aws_organizations_policy.deny_human_console_prod.id
    sandbox_auto_cleanup = aws_organizations_policy.sandbox_auto_cleanup.id
  }
}
