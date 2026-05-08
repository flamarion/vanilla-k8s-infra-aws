provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile

  default_tags {
    tags = {
      ManagedBy   = "terraform"
      Namespace   = var.namespace
      Environment = "lab"
    }
  }
}
