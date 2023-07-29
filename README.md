# saml-okta
The terraform project is used to configure the samlbug tenant.  This project is not designed to be run by anyone
other than Ed Lott.  It's provided as a concise reference to the configuration of the samlbug tenant.

The tenant defines a single OIDC application.  Users gain membership to this application by being a member of one of
the following groups:
* TEST_MANAGED - users in this group supply username/password when they log in.  They're required to use their email
address for MFA.  These uses also have to ability to click the 'Remember Me' checkbox during a login session so that a
device cookie is saved, allowing them to forego MFA for a configured window.
* TEST_SSO_PARTNER_MFA - users in this group SSO into the application (via the mock-saml companion app), attesting that
they have done MFA on their end so this application won't issue an MFA challenge.
* TEST_SSO - users in this group SSO into the application (via the mock-saml companion app), attesting that they have
not done MFA on their end so this application will issue an MFA challenge.  This is the group that experiences the
SSO-MFA bug.  Everytime they login, they'll get hit with an MFA challenge.  We want to fix things so that TEST_SSO users
have an challenge-avoidance window similar to TEST_MANAGED when they click the 'Rememer Me' checkbox.

All customized policies are tied to the user's membership to one of these groups.  The other settings on this tenant
hopefully don't impact the behavior of these policies.

Feel free to experiment with this tenant, as it's only being used to work-though this bug.
