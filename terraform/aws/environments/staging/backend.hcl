bucket         = "nexusdeploy-terraform-state"
key            = "aws/staging/terraform.tfstate"
region         = "us-east-1"
dynamodb_table = "nexusdeploy-terraform-locks"
encrypt        = true
