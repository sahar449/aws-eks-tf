# 1. Basic AWS Information
data "aws_caller_identity" "current" {}

# Random String Generator
resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

###################################
# 2. Load Balancer Controller Resources
###################################

# 2.1 Load Balancer Controller IAM Role and Policy
data "aws_iam_policy" "lb_controller_policy" {
  name = "AWSLoadBalancerControllerIAMPolicy"
}

resource "aws_iam_role" "lb_controller_role" {
  name = "eks-lb-controller-role-${random_string.suffix.result}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = var.oidc_provider_arn
        }
        Condition = {
          StringEquals = {
            "${replace(var.oidc_provider_url, "https://", "")}:sub" = "system:serviceaccount:kube-system:aws-load-balancer-controller"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lb_controller_attach" {
  role       = aws_iam_role.lb_controller_role.name
  policy_arn = data.aws_iam_policy.lb_controller_policy.arn
}

# 2.2 Load Balancer Controller Helm Release - יוצר service account אוטומטית
resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = "1.7.1"

  set {
    name  = "clusterName"
    value = var.cluster_name
  }

  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.lb_controller_role.arn
  }

  set {
    name  = "region"
    value = var.region
  }

  set {
    name  = "vpcId"
    value = var.vpc_id
  }

  depends_on = [
    aws_iam_role.lb_controller_role
  ]
}

###################################
# 3. External DNS Resources
###################################

# 3.1 External DNS IAM Policy and Role
resource "aws_iam_policy" "external_dns_policy" {
  name        = "ExternalDNSIAMPolicy-${random_string.suffix.result}"
  description = "IAM policy for External DNS to manage Route53 records"
  policy      = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "route53:ChangeResourceRecordSets",
          "route53:ListResourceRecordSets",
          "route53:ListHostedZones",
          "route53:ListTagsForResource"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role" "external_dns_role" {
  name = "eks-external-dns-role-${random_string.suffix.result}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = var.oidc_provider_arn
        }
        Condition = {
          StringEquals = {
            "${replace(var.oidc_provider_url, "https://", "")}:sub" = "system:serviceaccount:kube-system:external-dns"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "external_dns_attach" {
  role       = aws_iam_role.external_dns_role.name
  policy_arn = aws_iam_policy.external_dns_policy.arn
}

resource "aws_iam_role_policy_attachment" "dns_controller_policy" {
  role       = aws_iam_role.external_dns_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonRoute53FullAccess"
}

# 3.2 External DNS Helm Release 
resource "helm_release" "external_dns" {
  name       = "external-dns"
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "external-dns"
  namespace  = "kube-system"
  version    = "6.33.0"

  set {
    name  = "provider"
    value = "aws"
  }

  set {
    name  = "aws.zoneType"
    value = "public"
  }

  set {
    name  = "aws.region"
    value = var.region
  }

  set {
    name  = "txtOwnerId"
    value = var.cluster_name
  }

  set {
    name  = "policy"
    value = "upsert-only"
  }

  set {
    name  = "domainFilters[0]"
    value = "saharbittman.com"
  }

  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = "external-dns"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.external_dns_role.arn
  }

  set {
    name  = "sources[0]"
    value = "service"
  }

  set {
    name  = "sources[1]"
    value = "ingress"
  }

  depends_on = [
    helm_release.aws_load_balancer_controller,
    aws_iam_role.external_dns_role
  ]
}


###################################
# 4. Flask App Helm Release
###################################

resource "helm_release" "flask_app" {
  name       = "flask-app"
  chart      = "./flask-app"
  namespace  = "default"

  set {
    name  = "image.repository"
    value = var.repo_name
  }

  set {
    name  = "image.tag"
    value = "latest"
  }

  depends_on = [
    helm_release.aws_load_balancer_controller,
    helm_release.external_dns
  ]
}


# resource "helm_release" "flask_app" {
#   name       = "flask-app"
#   chart      = "./flask-app"
#   namespace  = "default"

#   set {
#     name  = "image.repository"
#     value = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.region}.amazonaws.com/test"
#   }

#   set {
#     name  = "image.tag"
#     value = "latest"
#   }

#   depends_on = [
#     helm_release.aws_load_balancer_controller,
#     helm_release.external_dns
#   ]
# }
