# ---------------------------------------------------------------------------
# ECR Module
#
# Private container registries for web (Next.js) and API (NestJS) images.
# Images are pushed via infra/scripts/build-and-push-ecr.sh.
#
# Lifecycle policies keep storage costs low by removing untagged images
# and retaining only the last 10 tagged releases per repository.
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Web application repository
# ---------------------------------------------------------------------------

resource "aws_ecr_repository" "web" {
  name                 = "${var.project_name}-${var.environment_name}-web"
  image_tag_mutability = "MUTABLE" # Allows re-pushing the same tag (e.g. latest)
  force_delete         = true      # Allow destroy even when images exist

  image_scanning_configuration {
    scan_on_push = true # Scan for vulnerabilities on every push
  }

  tags = merge(var.tags, {
    Name    = "${var.project_name}-${var.environment_name}-web"
    Service = "web"
  })
}

resource "aws_ecr_lifecycle_policy" "web" {
  repository = aws_ecr_repository.web.name

  policy = jsonencode({
    rules = [
      {
        # Remove untagged images after 1 day — these are intermediate build artifacts
        rulePriority = 1
        description  = "Remove untagged images after 1 day"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 1
        }
        action = { type = "expire" }
      },
      {
        # Keep only the last 10 tagged releases — enough history for rollbacks
        rulePriority = 2
        description  = "Keep last 10 tagged images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["v", "latest"]
          countType     = "imageCountMoreThan"
          countNumber   = 10
        }
        action = { type = "expire" }
      }
    ]
  })
}

# ---------------------------------------------------------------------------
# API application repository (service folder: apps/api-order)
# ---------------------------------------------------------------------------

resource "aws_ecr_repository" "api_order" {
  name                 = "${var.project_name}-${var.environment_name}-api-order"
  image_tag_mutability = "MUTABLE"
  force_delete         = true # Allow destroy even when images exist

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = merge(var.tags, {
    Name    = "${var.project_name}-${var.environment_name}-api-order"
    Service = "api-order"
  })
}

resource "aws_ecr_lifecycle_policy" "api_order" {
  repository = aws_ecr_repository.api_order.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Remove untagged images after 1 day"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 1
        }
        action = { type = "expire" }
      },
      {
        rulePriority = 2
        description  = "Keep last 10 tagged images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["v", "latest"]
          countType     = "imageCountMoreThan"
          countNumber   = 10
        }
        action = { type = "expire" }
      }
    ]
  })
}
