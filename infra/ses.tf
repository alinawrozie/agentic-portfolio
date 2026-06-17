# While the SES account is in sandbox mode (the default for new
# accounts), BOTH the sender and recipient addresses must be verified.
# Terraform can request verification, but you still have to click the
# confirmation link AWS emails to each address - that step can't be
# automated. Run `aws ses list-identities --identity-type EmailAddress`
# to check status, or look in the SES console under "Verified identities".
#
# To send to arbitrary recipients later (e.g. anyone who emails the
# real form), request SES production access - a short form in the
# SES console, usually approved within 24h.

locals {
  ses_identities = distinct([var.sender_email, var.recipient_email])
}

resource "aws_ses_email_identity" "verified" {
  for_each = toset(local.ses_identities)
  email    = each.value
}
