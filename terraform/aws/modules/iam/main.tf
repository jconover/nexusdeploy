locals {
  role_policy_attachments = flatten([
    for role_key, role in var.roles : [
      for policy_arn in role.managed_policy_arns : {
        role_key   = role_key
        policy_arn = policy_arn
      }
    ]
  ])

  custom_policy_role_attachments = flatten([
    for policy_key, policy in var.custom_policies : [
      for role_key in policy.role_keys : {
        policy_key = policy_key
        role_key   = role_key
      }
    ]
  ])
}

resource "aws_iam_role" "roles" {
  for_each = var.roles

  name        = each.key
  description = each.value.description

  assume_role_policy = each.value.assume_role_policy

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "managed" {
  for_each = {
    for item in local.role_policy_attachments :
    "${item.role_key}-${basename(item.policy_arn)}" => item
  }

  role       = aws_iam_role.roles[each.value.role_key].name
  policy_arn = each.value.policy_arn
}

resource "aws_iam_policy" "custom" {
  for_each = var.custom_policies

  name        = each.key
  description = each.value.description
  policy      = each.value.policy_document

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "custom" {
  for_each = {
    for item in local.custom_policy_role_attachments :
    "${item.role_key}-${item.policy_key}" => item
  }

  role       = aws_iam_role.roles[each.value.role_key].name
  policy_arn = aws_iam_policy.custom[each.value.policy_key].arn
}

resource "aws_iam_instance_profile" "profiles" {
  for_each = {
    for role_key, role in var.roles : role_key => role
    if role.create_instance_profile
  }

  name = each.key
  role = aws_iam_role.roles[each.key].name

  tags = var.tags
}
