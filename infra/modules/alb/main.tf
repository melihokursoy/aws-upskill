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
# Health checks: web → /nextapi/health, api → /api/health
# ---------------------------------------------------------------------------

resource "aws_lb_target_group" "web" {
  name        = "${var.project_name}-${var.environment_name}-web-tg"
  port        = 3300
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip" # Required for ECS Fargate (tasks have IP addresses, not instance IDs)

  health_check {
    path                = "/nextapi/health"
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

# HTTPS (port 443) → default forward to web service.
# The catch-all rule at priority 100 handles authentication for all other paths.
# This default action is a safety net and is never reached in practice.
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}

# ---------------------------------------------------------------------------
# Listener Rules — HTTPS listener
#
# Evaluation order (lower priority number = evaluated first):
#
#   1   /_next/*             → allow → web   (Next.js static assets)
#   2   /favicon.ico         → allow → web   (browser default icon)
#   3   /403                 → allow → web   (access denied page — public)
#   4   /nextapi/health      → allow → web   (web health check — no auth)
#   5   /auth/signout       → allow → web   (logout redirect — no session needed)
#   6   /api/health          → allow → api   (API health check — no auth)
#      /api/db-health        → allow → api
#   7   /                    → authenticate-cognito (allow) → web
#                              ALB forwards OIDC headers if session exists,
#                              passes through without headers if not.
#                              Allows home page to show auth state.
#  10   /api/*               → authenticate-cognito (authenticate) → api
#                              All other API routes require authentication.
# 100   /*                   → authenticate-cognito (authenticate) → web
#                              Catch-all: all other web routes require auth.
# ---------------------------------------------------------------------------

locals {
  # Shared Cognito session config used across all authenticate-cognito rules
  cognito_session_timeout = 3600
  cognito_scope           = "openid email profile phone"
}

# Priority 1 — Next.js static assets (/_next/*)
# Must be exempt from auth so CSS/JS loads on the Cognito login redirect page
resource "aws_lb_listener_rule" "public_next_static" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 1

  condition {
    path_pattern {
      values = ["/_next/*"]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}

# Priority 2 — Favicon
resource "aws_lb_listener_rule" "public_favicon" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 2

  condition {
    path_pattern {
      values = ["/favicon.ico"]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}

# Priority 3 — 403 Forbidden page (public error page)
resource "aws_lb_listener_rule" "public_403" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 3

  condition {
    path_pattern {
      values = ["/403", "/403/*"]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}

# Priority 4 — Web health check
resource "aws_lb_listener_rule" "public_health_web" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 4

  condition {
    path_pattern {
      values = ["/nextapi/health"]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}

# Priority 5 — Sign-out route (no session required — user may have expired session)
resource "aws_lb_listener_rule" "public_sign_out" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 5

  condition {
    path_pattern {
      values = ["/auth/signout"]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}

# Priority 6 — API health checks (must be before /api/* auth rule)
resource "aws_lb_listener_rule" "public_health_api" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 6

  condition {
    path_pattern {
      values = ["/api/health", "/api/db-health"]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api.arn
  }
}

# Priority 7 — Home page: auth-aware but not enforced
# authenticate-cognito with on_unauthenticated_request = "allow":
#   - If user has a valid ALB session cookie → forward with x-amzn-oidc-data header set
#   - If no valid session → forward without the header (unauthenticated access allowed)
# This lets the home page render the avatar dropdown for authenticated users.
resource "aws_lb_listener_rule" "home_auth_aware" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 7

  condition {
    path_pattern {
      values = ["/"]
    }
  }

  action {
    order = 1
    type  = "authenticate-cognito"

    authenticate_cognito {
      user_pool_arn              = var.cognito_user_pool_arn
      user_pool_client_id        = var.cognito_user_pool_client_id
      user_pool_domain           = var.cognito_user_pool_domain
      on_unauthenticated_request = "allow"
      scope                      = local.cognito_scope
      session_timeout            = local.cognito_session_timeout
    }
  }

  action {
    order            = 2
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}

# Priority 10 — API routes: authentication required
# Unauthenticated requests are redirected to Cognito Hosted UI.
# Health check paths (/api/health, /api/db-health) are exempt via higher-priority rules above.
resource "aws_lb_listener_rule" "api" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 10

  condition {
    path_pattern {
      values = ["/api/*"]
    }
  }

  action {
    order = 1
    type  = "authenticate-cognito"

    authenticate_cognito {
      user_pool_arn              = var.cognito_user_pool_arn
      user_pool_client_id        = var.cognito_user_pool_client_id
      user_pool_domain           = var.cognito_user_pool_domain
      on_unauthenticated_request = "authenticate"
      scope                      = local.cognito_scope
      session_timeout            = local.cognito_session_timeout
    }
  }

  action {
    order            = 2
    type             = "forward"
    target_group_arn = aws_lb_target_group.api.arn
  }
}

# Priority 100 — All other web routes: authentication required
# Catch-all for /manage, /admin, and any future protected pages.
# Unauthenticated requests are redirected to Cognito Hosted UI.
resource "aws_lb_listener_rule" "web_authenticated" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 100

  condition {
    path_pattern {
      values = ["/*"]
    }
  }

  action {
    order = 1
    type  = "authenticate-cognito"

    authenticate_cognito {
      user_pool_arn              = var.cognito_user_pool_arn
      user_pool_client_id        = var.cognito_user_pool_client_id
      user_pool_domain           = var.cognito_user_pool_domain
      on_unauthenticated_request = "authenticate"
      scope                      = local.cognito_scope
      session_timeout            = local.cognito_session_timeout
    }
  }

  action {
    order            = 2
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}
