bucket         = "nexusdeploy-terraform-state"
key            = "aws/dev/terraform.tfstate"
region         = "us-east-1"
dynamodb_table = "nexusdeploy-terraform-locks"
encrypt        = true
