variable "issuer" {
  description = "Partner issuer"
  type = string
}

variable "name" {
  description = "Name of IDP in Okta"
  type = string
}

variable "prefix" {
  description = "Prefix of user-name in Okta for users of this IDP"
  type = string
}

variable "sso_url" {
  description = "SSO origin"
  type = string
}

variable "public_cert" {
  description = "Registered public certificate"
  type = string
}

variable "noMfaGroupId" {
  description = "Group ID of non-mfa group"
  type = string
}

variable "mfaGroupId" {
  description = "Group ID of mfa group"
  type = string
}

variable "createRun" {
  description = "For the first run, this should be true"
  type = bool
}
