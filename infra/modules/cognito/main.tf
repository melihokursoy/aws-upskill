# ---------------------------------------------------------------------------
# Cognito Module
#
# Creates:
#   - User Pool with email-as-username and optional self-registration
#   - Hosted UI AWS subdomain (<project>-<env>.auth.<region>.amazoncognito.com)
#   - App Client configured for ALB OIDC (Authorization Code Grant)
#   - Three User Pool Groups: admin, moderator, user
#
# The ALB uses authenticate-cognito action to redirect unauthenticated users
# to the Hosted UI. The app never handles raw tokens — ALB validates and
# forwards decoded JWT claims via the x-amzn-oidc-data header.
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# User Pool
# ---------------------------------------------------------------------------

resource "aws_cognito_user_pool" "main" {
  name = "${var.project_name}-${var.environment_name}"

  # Email is the username — users sign in with their email address
  username_attributes      = ["email"]
  auto_verified_attributes = ["email"]

  # Self-registration control — set allow_self_registration = false to restrict
  # user creation to admins only (e.g. tighter staging/prod environments)
  admin_create_user_config {
    allow_admin_create_user_only = !var.allow_self_registration
  }

  # Password complexity requirements — must be satisfied by seed script passwords too
  password_policy {
    minimum_length                   = 8
    require_uppercase                = true
    require_lowercase                = true
    require_numbers                  = true
    require_symbols                  = true
    temporary_password_validity_days = 7
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment_name}-user-pool"
  })
}

# ---------------------------------------------------------------------------
# Hosted UI Domain (AWS subdomain — no custom domain)
#
# Resulting URL: https://<domain>.auth.<region>.amazoncognito.com
# Domain prefix must be globally unique in the AWS region.
# ---------------------------------------------------------------------------

resource "aws_cognito_user_pool_domain" "main" {
  # Domain prefix only — full URL is constructed in outputs.
  # Strip "aws-" prefix: Cognito rejects domain names containing the reserved word "aws".
  # e.g. "aws-upskill-dev" → "upskill-dev"
  domain       = replace("${var.project_name}-${var.environment_name}", "aws-", "")
  user_pool_id = aws_cognito_user_pool.main.id
}

# ---------------------------------------------------------------------------
# App Client — ALB OIDC
#
# generate_secret = true: ALB retrieves the client secret automatically via
# IAM when performing the Authorization Code token exchange. The secret is
# never exposed to browsers or application code.
#
# callback_urls: ALB's fixed OIDC callback endpoint. Cognito rejects
# redirects to any URL not in this list.
# ---------------------------------------------------------------------------

resource "aws_cognito_user_pool_client" "alb" {
  name         = "${var.project_name}-${var.environment_name}-alb"
  user_pool_id = aws_cognito_user_pool.main.id

  # Required for ALB token exchange — ALB retrieves this via IAM, never exposed
  generate_secret = true

  # OAuth 2.0 Authorization Code Grant for server-side OIDC (ALB pattern)
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_flows                  = ["code"]

  # Scopes map to JWT claims:
  #   openid  → sub
  #   email   → email, email_verified
  #   profile → name, family_name, given_name, picture, gender, birthdate, zoneinfo, locale
  #   phone   → phone_number
  allowed_oauth_scopes = ["openid", "email", "profile", "phone"]

  supported_identity_providers = ["COGNITO"]

  # ALB's fixed OIDC callback endpoint — Cognito redirects here after auth
  callback_urls = ["https://${var.app_domain}/oauth2/idpresponse"]

  # Post-logout redirect — browser lands here after Cognito clears its session
  logout_urls = ["https://${var.app_domain}"]

  # All standard OIDC attributes that this client can read/write
  read_attributes = [
    "email", "name", "given_name", "family_name", "picture",
    "birthdate", "phone_number", "address", "gender", "locale", "zoneinfo",
  ]

  write_attributes = [
    "email", "name", "given_name", "family_name", "picture",
    "birthdate", "phone_number", "address", "gender", "locale", "zoneinfo",
  ]
}

# ---------------------------------------------------------------------------
# User Pool Groups — map to application roles
#
# Precedence determines which group's claims take priority if a user
# belongs to multiple groups (lower number = higher priority).
# ---------------------------------------------------------------------------

resource "aws_cognito_user_group" "admin" {
  name         = "admin"
  user_pool_id = aws_cognito_user_pool.main.id
  description  = "Administrator role — highest privilege"
  precedence   = 1
}

resource "aws_cognito_user_group" "moderator" {
  name         = "moderator"
  user_pool_id = aws_cognito_user_pool.main.id
  description  = "Moderator role — intermediate privilege"
  precedence   = 2
}

resource "aws_cognito_user_group" "user" {
  name         = "user"
  user_pool_id = aws_cognito_user_pool.main.id
  description  = "Standard user role"
  precedence   = 3
}
