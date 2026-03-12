resource "aws_secretsmanager_secret" "secrets" {
  for_each = var.secrets

  name        = each.key
  description = each.value.description
  kms_key_id  = var.kms_key_id

  recovery_window_in_days = var.recovery_window_in_days

  tags = merge(var.tags, each.value.tags)
}

resource "aws_secretsmanager_secret_version" "versions" {
  for_each = { for k, v in var.secrets : k => v if v.value != null }

  secret_id     = aws_secretsmanager_secret.secrets[each.key].id
  secret_string = each.value.value

  lifecycle {
    ignore_changes = [secret_string]
  }
}
