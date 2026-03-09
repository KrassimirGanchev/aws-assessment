locals {
  aws_region = "us-east-1"

  availability_zones = [
    "us-east-1a",
    "us-east-1b"
  ]

  vpc = {
    name                   = "aws-assessment-dev-us-east-1-vpc"
    vpc_cidr               = "10.20.0.0/16"
    public_subnet_cidrs    = ["10.20.1.0/24", "10.20.2.0/24"]
    private_subnet_cidrs   = ["10.20.11.0/24", "10.20.12.0/24"]
    create_private_subnets = false
    enable_nat_gateway     = false
    single_nat_gateway     = false
  }
}
