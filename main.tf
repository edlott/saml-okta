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
      mfa_lifetime = 3
      password_max_age_days = 90
      password_min_age_minutes = 0
    }
    ed-dev = {
      org_name = "dev-71459526"
      base_url = "okta.com"
      redirect_callback_env = ["http://localhost:3000/loginCallback"]
      redirect_logout_env = ["http://localhost:3000/logout"]
      re_authentication_frequency = "PT720H"
      access_token_lifetime_minutes = 5
      refresh_token_lifetime_minutes = 5
      refresh_token_window_minutes = 5
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
  name = "SSO Users"
  groups_included = [
    okta_group.ssoNoMFA.id,
    okta_group.ssoMFA.id,
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
  re_authentication_frequency = "PT0S"
}

resource "okta_app_signon_policy_rule" "denyAll" {
  policy_id = okta_app_signon_policy.myMatrixExternal.id
  name = "Deny All"
  priority = 3
  access = "DENY"
}

/********** Global Session policies **********/

data "okta_behavior" "new_device" {
  name = "New Device"
}

resource "okta_policy_signon" "externalNetworkAccess" {
  name = "MME Managed Users2"
  description = "MME Managed Users"
  priority = 1
  groups_included = [
    okta_group.managed.id
  ]
}

resource "okta_policy_rule_signon" "externalNetworkAccess" {
  name = "MME Managed Users2"
  policy_id = okta_policy_signon.externalNetworkAccess.id
  session_idle = 1
  session_lifetime = 5
  session_persistent = false
  mfa_required = true
  mfa_prompt = "SESSION"
  mfa_lifetime = "${local.workspace["mfa_lifetime"]}"
  network_connection = "ANYWHERE"
  risc_level = "ANY"
}

resource "okta_policy_signon" "externalNetworkAccessNoMFA" {
  name = "MME SSO Users No MFA2"
  description = "MME SSO Users No MFA"
  priority = 2
  groups_included = [
    okta_group.ssoNoMFA.id
  ]
}

resource "okta_policy_rule_signon" "externalNetworkAccessNoMFA" {
  name = "MME SSO Users No MFA2"
  policy_id = okta_policy_signon.externalNetworkAccessNoMFA.id
  session_idle = 1
  session_lifetime = 1
  session_persistent = false
  mfa_required = false
  network_connection  = "ANYWHERE"
  risc_level = "ANY"
}

resource "okta_policy_signon" "externalNetworkAccessMFA" {
  name = "MME SSO Users MFA2"
  description = "MME SSO Users MFA"
  priority = 3
  groups_included = [
    okta_group.ssoMFA.id
  ]
}

resource "okta_policy_rule_signon" "ssoNewDevice" {
  name = "MME SSO Users New Device2"
  policy_id = okta_policy_signon.externalNetworkAccessMFA.id
  behaviors = [
    data.okta_behavior.new_device.id
  ]
  session_idle = 1
  session_lifetime = 5
  session_persistent = false
  mfa_required = true
  mfa_prompt = "DEVICE"
  network_connection  = "ANYWHERE"
  risc_level = "ANY"
  priority = 1
}

resource "okta_policy_rule_signon" "ssoExistingDevice" {
  name = "MME SSO Users Existing Device2"
  policy_id = okta_policy_signon.externalNetworkAccessMFA.id
  session_idle = 1
  session_lifetime = 1
  session_persistent = false
  mfa_required = false
  network_connection  = "ANYWHERE"
  risc_level = "ANY"
  priority = 2
}

resource "okta_policy_signon" "failAll" {
  description = "MME Users CatchAll"
  name = "MME Users CatchAll"
  priority = 4
  groups_included = [
    okta_group.managed.id,
    okta_group.ssoMFA.id,
    okta_group.ssoNoMFA.id
  ]
}

resource "okta_policy_rule_signon" "failAll" {
  name = "MME Users CatchAll"
  policy_id = okta_policy_signon.failAll.id
  access = "DENY"
}

/********** Authenticator Enrollment **********/

resource "okta_policy_mfa" "emailMfa" {
  description       = "Managed User MFA settings"
  groups_included = [
    okta_group.managed.id,
    okta_group.ssoMFA.id
  ]
  is_oie = true
  name = "MME Managed User MFA settings"
  okta_email        = {
    "enroll" = "REQUIRED"
  }
  okta_password        = {
    "enroll" = "REQUIRED"
  }
  phone_number      = {
    "enroll" = "NOT_ALLOWED"
  }
  priority          = 1
  security_question = {
    "enroll" = "REQUIRED"
  }
}

resource "okta_policy_rule_mfa" "catchAll" {
  name = "CatchAll"
  policy_id = okta_policy_mfa.emailMfa.id
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

/********** CORS **********/

resource "okta_trusted_origin" "localDev" {
  name = "localDev"
  origin = "http://localhost:3000/"
  scopes = ["CORS","REDIRECT"]
}

/********** Test managed users **********/

resource "okta_user" "managed1" {
  first_name = "Ed"
  last_name = "Lott"
  login = "elott@samlbug.org"
  email = "edlott@sbcglobal.net"
}

resource "okta_user_group_memberships" "managed1" {
  user_id = okta_user.managed1.id
  groups = [
    okta_group.managed.id
  ]
}
