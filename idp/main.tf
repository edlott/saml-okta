terraform {
  required_providers {
    okta = {
      source = "okta/okta"
      version = "3.44.0"
    }
  }
}

data "okta_user_profile_mapping_source" "user" {}

resource "okta_idp_saml" "idp" {
  groups_action = "SYNC"
  groups_attribute = "mfaSetting"
  groups_filter = [
    var.noMfaGroupId,
    var.mfaGroupId
  ]
  issuer = var.issuer
  kid = var.public_cert
  name = var.name
  profile_master = true
  sso_url = var.sso_url
  username_template = "'${var.prefix}' + idpuser.subjectNameId"
}

resource "okta_profile_mapping" "idpEmpty" {
  count = var.createRun ? 1 : 0
  source_id = okta_idp_saml.idp.id
  target_id = data.okta_user_profile_mapping_source.user.id
  delete_when_absent = true
  mappings {
    id = "login"
    expression = "source.userName"
    push_status = "PUSH"
  }
}

resource "okta_profile_mapping" "idp" {
  count = !var.createRun ? 1 : 0
  source_id = okta_idp_saml.idp.id
  target_id = data.okta_user_profile_mapping_source.user.id
  delete_when_absent = true

  mappings {
    id = "login"
    expression = "source.userName"
    push_status = "PUSH"
  }
  mappings {
    id = "firstName"
    expression = "source.firstName"
    push_status = "PUSH"
  }
  mappings {
    id = "lastName"
    expression = "source.lastName"
    push_status = "PUSH"
  }
  mappings {
    id         = "email"
    expression = "(appuser.email != null) ? appuser.email : appuser.subjectNameId"
    push_status = "PUSH"
  }
}
