locals {
  aws_region = "eu-west-1"

  availability_zones = [
    "eu-west-1a",
    "eu-west-1b"
  ]

  vpc = {
    name                   = "aws-assessment-dev-eu-west-1-vpc"
    vpc_cidr               = "10.10.0.0/16"
    public_subnet_cidrs    = ["10.10.1.0/24", "10.10.2.0/24"]
    private_subnet_cidrs   = ["10.10.11.0/24", "10.10.12.0/24"]
    create_private_subnets = false
    enable_nat_gateway     = false
    single_nat_gateway     = false
  }
}
