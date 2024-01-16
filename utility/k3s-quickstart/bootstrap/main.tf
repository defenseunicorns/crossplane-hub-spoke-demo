data "aws_partition" "current" {}

data "aws_caller_identity" "current" {}

resource "random_id" "default" {
  byte_length = 2
}

locals {
  vpc_name                   = "${var.name_prefix}-${lower(random_id.default.hex)}"
  cluster_name               = "${var.name_prefix}-${lower(random_id.default.hex)}"
  bastion_name               = "${var.name_prefix}-bastion-${lower(random_id.default.hex)}"
  access_logging_name_prefix = "${var.name_prefix}-accesslog-${lower(random_id.default.hex)}"
  kms_key_alias_name_prefix  = "alias/${var.name_prefix}-${lower(random_id.default.hex)}"
  access_log_sqs_queue_name  = "${var.name_prefix}-accesslog-access-${lower(random_id.default.hex)}"
  tags = merge(
    var.tags,
    {
      RootTFModule = replace(basename(path.cwd), "_", "-") # tag names based on the directory name
      GithubRepo   = "github.com/defenseunicorns/delivery-aws-iac"
    }
  )
}

################################################################################
# VPC
################################################################################

module "vpc" {
  source = "git::https://github.com/defenseunicorns/terraform-aws-uds-vpc.git?ref=v0.0.5"

  name                  = local.vpc_name
  vpc_cidr              = var.vpc_cidr
  secondary_cidr_blocks = var.secondary_cidr_blocks
  azs                   = ["${var.region}a", "${var.region}b", "${var.region}c"]
  public_subnets        = [for k, v in module.vpc.azs : cidrsubnet(module.vpc.vpc_cidr_block, 5, k)]
  private_subnets       = [for k, v in module.vpc.azs : cidrsubnet(module.vpc.vpc_cidr_block, 5, k + 4)]
  database_subnets      = [for k, v in module.vpc.azs : cidrsubnet(module.vpc.vpc_cidr_block, 5, k + 8)]
  intra_subnets         = [for k, v in module.vpc.azs : cidrsubnet(element(module.vpc.vpc_secondary_cidr_blocks, 0), 5, k)]
  single_nat_gateway    = true
  enable_nat_gateway    = true

  private_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"             = 1
  }
  create_database_subnet_group = true

  instance_tenancy                  = "default"
  vpc_flow_log_permissions_boundary = var.iam_role_permissions_boundary

  tags = local.tags
}

################################################################################
# Bastion instance
################################################################################

locals {
  bastion_role_arn  = try(module.bastion[0].bastion_role_arn, "")
  bastion_role_name = try(module.bastion[0].bastion_role_name, "")

  enable_bastion_access = length(local.bastion_role_arn) > 0 && length(local.bastion_role_name) > 0

  # if bastion role vars are defined, add bastion role to aws_auth_roles list
  bastion_aws_auth_entry = local.enable_bastion_access ? [
    {
      rolearn  = local.bastion_role_arn
      username = local.bastion_role_name
      groups   = ["system:masters"]
  }] : []
}

data "aws_ami" "amazonlinux2" {
  count = var.enable_bastion ? 1 : 0

  most_recent = true

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm*x86_64-gp2"]
  }

  owners = ["amazon"]
}

module "bastion" {
  source = "git::https://github.com/defenseunicorns/terraform-aws-uds-bastion.git?ref=v0.0.5"

  count = var.enable_bastion ? 1 : 0

  enable_bastion_terraform_permissions = true

  ami_id        = data.aws_ami.amazonlinux2[0].id
  instance_type = var.bastion_instance_type
  root_volume_config = {
    volume_type = "gp3"
    volume_size = "20"
    encrypted   = true
  }
  name                           = local.bastion_name
  vpc_id                         = module.vpc.vpc_id
  subnet_id                      = module.vpc.private_subnets[0]
  region                         = var.region
  access_logs_bucket_name        = aws_s3_bucket.access_log_bucket.id
  session_log_bucket_name_prefix = "${local.bastion_name}-sessionlogs"
  kms_key_arn                    = aws_kms_key.default.arn
  ssh_user                       = var.bastion_ssh_user
  ssh_password                   = var.bastion_ssh_password
  assign_public_ip               = false
  enable_log_to_s3               = true
  enable_log_to_cloudwatch       = true
  tenancy                        = var.bastion_tenancy
  zarf_version                   = var.zarf_version
  permissions_boundary           = var.iam_role_permissions_boundary
  tags = merge(
    local.tags,
  { Function = "bastion-ssm" })
}
