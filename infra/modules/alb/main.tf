# ---------------------------------------------------------------------------
# ALB Module
#
# Application Load Balancer with:
#   - HTTPS listener (port 443) using ACM certificate
#   - HTTP listener (port 80) that redirects to HTTPS
#   - Path-based routing: /api/* → API service, /* → web service
#   - Health checks on /health for both services
#   - Connection draining for graceful rolling deployments
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Security Group — controls traffic in/out of the ALB
# ---------------------------------------------------------------------------

resource "aws_security_group" "alb" {
  name        = "${var.project_name}-${var.environment_name}-alb-sg"
  description = "Allow HTTP and HTTPS inbound to ALB from the internet"
  vpc_id      = var.vpc_id

  # Allow HTTP from anywhere (redirects to HTTPS)
  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow HTTPS from anywhere
  ingress {
    description = "HTTPS from internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound (ALB needs to reach ECS tasks in private subnet)
  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment_name}-alb-sg"
  })
}

# ---------------------------------------------------------------------------
# Application Load Balancer
# ---------------------------------------------------------------------------

resource "aws_lb" "main" {
  name               = "${var.project_name}-${var.environment_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.public_subnet_ids

  # Protect against accidental deletion
  enable_deletion_protection = false

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment_name}-alb"
  })
}

# ---------------------------------------------------------------------------
# Target Groups
# ECS tasks register themselves with these target groups.
# Health check on /health — both web and API must implement this endpoint.
# ---------------------------------------------------------------------------

resource "aws_lb_target_group" "web" {
  name        = "${var.project_name}-${var.environment_name}-web-tg"
  port        = 3300
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip" # Required for ECS Fargate (tasks have IP addresses, not instance IDs)

  health_check {
    path                = "/api/health"
    protocol            = "HTTP"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200"
  }

  # Connection draining — wait for in-flight requests to complete during rolling deployments
  deregistration_delay = 30

  tags = merge(var.tags, {
    Name    = "${var.project_name}-${var.environment_name}-web-tg"
    Service = "web"
  })
}

resource "aws_lb_target_group" "api" {
  name        = "${var.project_name}-${var.environment_name}-api-tg"
  port        = 3301
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip" # Required for ECS Fargate

  health_check {
    path                = "/health"
    protocol            = "HTTP"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200"
  }

  # Connection draining — wait for in-flight requests to complete during rolling deployments
  deregistration_delay = 30

  tags = merge(var.tags, {
    Name    = "${var.project_name}-${var.environment_name}-api-tg"
    Service = "api"
  })
}

# ---------------------------------------------------------------------------
# Listeners
# ---------------------------------------------------------------------------

# HTTP (port 80) → redirect to HTTPS permanently
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# HTTPS (port 443) → default to web target group
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.certificate_arn

  # Default action: forward to web service
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}

# ---------------------------------------------------------------------------
# Listener Rules — path-based routing on HTTPS listener
# ---------------------------------------------------------------------------

# /api/* → API service (higher priority = evaluated first)
resource "aws_lb_listener_rule" "api" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 10

  condition {
    path_pattern {
      values = ["/api/*"]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api.arn
  }
}
