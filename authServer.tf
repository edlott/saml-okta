data "okta_auth_server" "default" {
  name = "default"
}

resource "okta_auth_server_policy" "mmExternal" {
  auth_server_id = data.okta_auth_server.default.id
  client_whitelist = [okta_app_oauth.mmExternal.client_id]
  description = "Policy for scopes in myMatrixx-External"
  name = "MME myMatrixx-External"
  priority = 1
}

resource "okta_auth_server_policy_rule" "Managed" {
  auth_server_id = data.okta_auth_server.default.id
  name = "Managed"
  policy_id = okta_auth_server_policy.mmExternal.id
  priority = 1

  group_whitelist = [
    okta_group.managed.id
  ]
  grant_type_whitelist = [
    "authorization_code",
    "interaction_code",
    "password",
  ]
  scope_whitelist = [
    "esrx.default",
    "offline_access",
    "openid"
  ]

  access_token_lifetime_minutes = "${local.workspace["access_token_lifetime_minutes"]}"
}

resource "okta_auth_server_policy_rule" "SSO" {
  auth_server_id = data.okta_auth_server.default.id
  name = "SSO"
  policy_id = okta_auth_server_policy.mmExternal.id
  priority = 2

  group_whitelist = [
    okta_group.ssoMFA.id,
    okta_group.ssoNoMFA.id
  ]
  grant_type_whitelist = [
    "authorization_code",
    "interaction_code",
    "password",
  ]
  scope_whitelist = [
    "esrx.default",
    "offline_access",
    "openid"
  ]

  access_token_lifetime_minutes = "${local.workspace["access_token_lifetime_minutes"]}"
  refresh_token_lifetime_minutes = "${local.workspace["refresh_token_lifetime_minutes"]}"
  refresh_token_window_minutes = "${local.workspace["refresh_token_window_minutes"]}"
}

resource "okta_auth_server_scope" "esrx_default" {
  auth_server_id = data.okta_auth_server.default.id
  description = "Created by Auth Admin"
  metadata_publish = "NO_CLIENTS"
  name = "esrx.default"
}

resource "okta_auth_server_claim" "esrx_displayName" {
  auth_server_id = data.okta_auth_server.default.id
  claim_type = "RESOURCE"
  status = "ACTIVE"
  value_type = "EXPRESSION"
  name = "esrx.displayName"
  value = "user.displayName"
  scopes = [
    "esrx.default"
  ]
}

resource "okta_auth_server_claim" "esrx_firstName" {
  auth_server_id = data.okta_auth_server.default.id
  claim_type = "RESOURCE"
  status = "ACTIVE"
  value_type = "EXPRESSION"
  name = "esrx.firstName"
  value = "user.firstName"
  scopes = [
    "esrx.default"
  ]
}

resource "okta_auth_server_claim" "esrx_lastName" {
  auth_server_id = data.okta_auth_server.default.id
  claim_type = "RESOURCE"
  status = "ACTIVE"
  value_type = "EXPRESSION"
  name = "esrx.lastName"
  value = "user.lastName"
  scopes = [
    "esrx.default"
  ]
}

resource "okta_auth_server_claim" "esrx_emailAddress" {
  auth_server_id = data.okta_auth_server.default.id
  claim_type = "RESOURCE"
  status = "ACTIVE"
  value_type = "EXPRESSION"
  name = "esrx.emailAddress"
  value = "user.email"
  scopes = [
    "esrx.default"
  ]
}

