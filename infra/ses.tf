# SES starts every new account in "sandbox" mode, where you can only send
# TO and FROM addresses you've manually verified - this is enough for a
# personal contact form where you are the only recipient. Terraform creates
# the verification request; you still have to click the confirmation link
# AWS emails you (this is an SES anti-abuse requirement, not something any
# amount of automation can skip).
#
# If you later want the form to work for arbitrary senders without
# verifying every visitor's email, request SES production access in the
# AWS console - Terraform can't automate that approval step either, since
# it involves a manual AWS review.

resource "aws_ses_email_identity" "sender" {
  email = var.ses_sender_email
}

resource "aws_ses_email_identity" "recipient" {
  count = var.ses_sender_email != var.contact_form_recipient_email ? 1 : 0
  email = var.contact_form_recipient_email
}
