terraform {
  required_providers {
    okta = {
      source = "okta/okta"
      version = "3.44.0"
    }
  }
}

/********** Environments **********/

locals {
  env = {
    default = {
      mfa_lifetime = 1
      password_max_age_days = 90
      password_min_age_minutes = 0
    }
    ed-dev = {
      org_name = "dev-71459526"
      base_url = "okta.com"
      redirect_callback_env = ["http://localhost:3000/login/callback"]
      redirect_logout_env = ["http://localhost:3000/logout"]
      re_authentication_frequency = "PT720H"
      access_token_lifetime_minutes = 5
      refresh_token_lifetime_minutes = 5
      refresh_token_window_minutes = 5
      okta_policy_mfa_priority = 1
    }
  }

  environmentvars = "${contains(keys(local.env), terraform.workspace) ? terraform.workspace : "default"}"
  workspace = "${merge(local.env["default"], local.env[local.environmentvars])}"
}

provider "okta" {
  org_name = "${local.workspace["org_name"]}"
  base_url = "${local.workspace["base_url"]}"
}

/********** Groups **********/

resource "okta_group" "ssoMFA" {
  name = "TEST_SSO"
}

resource "okta_group" "ssoNoMFA" {
  name = "TEST_SSO_PARTNER_MFA"
}

resource "okta_group" "managed" {
  name = "TEST_MANAGED"
}

/********** Application Authentication Policy **********/

resource "okta_app_signon_policy" "myMatrixExternal" {
  name = "myMatrixx-External Policy"
  description = "Policy for myMatrixx-External"
}

resource "okta_app_signon_policy_rule" "mfaHandledOrIgnored" {
  policy_id = okta_app_signon_policy.myMatrixExternal.id
  name = "MME MFA Handled or Ignored"
  groups_included = [
    okta_group.ssoNoMFA.id,
    okta_group.managed.id
  ]
  priority = 1
  constraints = [
    jsonencode({
      knowledge = {
        types = [
          "password",
        ]
      }
    }),
  ]
  factor_mode = "1FA"
  re_authentication_frequency = "PT43800H"
}

resource "okta_app_signon_policy_rule" "denyAll" {
  policy_id = okta_app_signon_policy.myMatrixExternal.id
  name = "Deny All"
  priority = 2
  access = "DENY"
}

/********** Global Session policies **********/

resource "okta_policy_signon" "externalNetworkAccess" {
  description = "Allow external users to access the application"
  name = "MME Managed Users"
  priority = 1
  groups_included = [
    okta_group.managed.id
  ]
}

resource "okta_policy_rule_signon" "externalNetworkAccess" {
  name = "MME Managed Users"
  policy_id = okta_policy_signon.externalNetworkAccess.id
  session_idle = 720
  session_lifetime = 0
  session_persistent = true
  mfa_lifetime = "${local.workspace["mfa_lifetime"]}"
  mfa_prompt = "SESSION"
  mfa_required = true
  network_connection = "ANYWHERE"
  risc_level = "ANY"
}

resource "okta_policy_signon" "externalNetworkAccessNoMFA" {
  name = "MME Users No MFA"
  description = "Allow SSO users to access the application without MFA"
  priority = 2
  groups_included = [
    okta_group.ssoNoMFA.id
  ]
}

resource "okta_policy_rule_signon" "externalNetworkAccessNoMFA" {
  name = "MME Users No MFA"
  policy_id = okta_policy_signon.externalNetworkAccessNoMFA.id
  session_idle = 720
  session_lifetime = 0
  session_persistent = true
  mfa_required = false
  network_connection  = "ANYWHERE"
  risc_level = "ANY"
}

/********** Application **********/

resource "okta_app_oauth" "mmExternal" {
  authentication_policy = okta_app_signon_policy.myMatrixExternal.id
  accessibility_self_service = false
  label = "myMatrixx-External"
  type = "browser"
  grant_types = [
    "authorization_code",
    "interaction_code",
    "refresh_token"
  ]
  issuer_mode = "DYNAMIC"
  lifecycle {
    ignore_changes = [groups]
  }
  omit_secret = true
  post_logout_redirect_uris = local.workspace.redirect_logout_env
  redirect_uris = local.workspace.redirect_callback_env
  response_types = [
    "code"
  ]
  skip_groups = false
  skip_users = true
  token_endpoint_auth_method = "none"
}

resource "okta_app_group_assignments" "mmExternal" {
  app_id = okta_app_oauth.mmExternal.id

  group {
    id = okta_group.ssoMFA.id
    priority = 1
  }
  group {
    id = okta_group.ssoNoMFA.id
    priority = 2
  }
  group {
    id = okta_group.managed.id
    priority = 3
  }
}
