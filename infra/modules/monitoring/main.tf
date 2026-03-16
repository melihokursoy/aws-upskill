# ---------------------------------------------------------------------------
# Monitoring Module
#
# CloudWatch alarms and dashboard for the ECS + ALB infrastructure.
#
# Alarms:
#   - ECS CPU utilization > 80% (web + api)
#   - ECS Memory utilization > 85% (web + api)
#   - ALB unhealthy target count > 0
#   - ECS running task count < min_task_count (task failures)
#
# Dashboard: unified view of ECS and ALB metrics.
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# ECS CPU Alarms
# ---------------------------------------------------------------------------

resource "aws_cloudwatch_metric_alarm" "web_cpu_high" {
  alarm_name          = "${var.project_name}-${var.environment_name}-web-cpu-high"
  alarm_description   = "Web service CPU > 80% — may need manual investigation or scaling limit increase"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 300 # 5 minutes
  statistic           = "Average"
  threshold           = 80
  treat_missing_data  = "notBreaching"

  dimensions = {
    ClusterName = var.cluster_name
    ServiceName = var.web_service_name
  }

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "api_cpu_high" {
  alarm_name          = "${var.project_name}-${var.environment_name}-api-cpu-high"
  alarm_description   = "API service CPU > 80% — may need manual investigation or scaling limit increase"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  treat_missing_data  = "notBreaching"

  dimensions = {
    ClusterName = var.cluster_name
    ServiceName = var.api_service_name
  }

  tags = var.tags
}

# ---------------------------------------------------------------------------
# ECS Memory Alarms
# ---------------------------------------------------------------------------

resource "aws_cloudwatch_metric_alarm" "web_memory_high" {
  alarm_name          = "${var.project_name}-${var.environment_name}-web-memory-high"
  alarm_description   = "Web service memory > 85% — containers approaching OOM limit"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = 300
  statistic           = "Average"
  threshold           = 85
  treat_missing_data  = "notBreaching"

  dimensions = {
    ClusterName = var.cluster_name
    ServiceName = var.web_service_name
  }

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "api_memory_high" {
  alarm_name          = "${var.project_name}-${var.environment_name}-api-memory-high"
  alarm_description   = "API service memory > 85% — containers approaching OOM limit"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = 300
  statistic           = "Average"
  threshold           = 85
  treat_missing_data  = "notBreaching"

  dimensions = {
    ClusterName = var.cluster_name
    ServiceName = var.api_service_name
  }

  tags = var.tags
}

# ---------------------------------------------------------------------------
# ALB Unhealthy Target Alarm
# Any unhealthy target means traffic is being routed to a failing container.
# ---------------------------------------------------------------------------

resource "aws_cloudwatch_metric_alarm" "alb_unhealthy_targets" {
  alarm_name          = "${var.project_name}-${var.environment_name}-alb-unhealthy-targets"
  alarm_description   = "ALB has unhealthy targets — one or more ECS tasks failing health checks"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Maximum"
  threshold           = 0
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = var.alb_arn_suffix
  }

  tags = var.tags
}

# ---------------------------------------------------------------------------
# ECS Task Failure Alarm
# Fires when running task count drops below minimum (tasks crashing/not starting).
# ---------------------------------------------------------------------------

resource "aws_cloudwatch_metric_alarm" "web_tasks_low" {
  alarm_name          = "${var.project_name}-${var.environment_name}-web-tasks-low"
  alarm_description   = "Web running task count below minimum — tasks may be crashing"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "RunningTaskCount"
  namespace           = "ECS/ContainerInsights"
  period              = 60
  statistic           = "Average"
  threshold           = var.min_task_count
  treat_missing_data  = "breaching"

  dimensions = {
    ClusterName = var.cluster_name
    ServiceName = var.web_service_name
  }

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "api_tasks_low" {
  alarm_name          = "${var.project_name}-${var.environment_name}-api-tasks-low"
  alarm_description   = "API running task count below minimum — tasks may be crashing"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "RunningTaskCount"
  namespace           = "ECS/ContainerInsights"
  period              = 60
  statistic           = "Average"
  threshold           = var.min_task_count
  treat_missing_data  = "breaching"

  dimensions = {
    ClusterName = var.cluster_name
    ServiceName = var.api_service_name
  }

  tags = var.tags
}

# ---------------------------------------------------------------------------
# CloudWatch Dashboard
# Unified view: ECS CPU/memory/task counts + ALB request count and latency.
# ---------------------------------------------------------------------------

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project_name}-${var.environment_name}"

  dashboard_body = jsonencode({
    widgets = [
      # Row 1: ECS CPU utilization
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "ECS CPU Utilization (%)"
          region = var.region
          metrics = [
            ["AWS/ECS", "CPUUtilization", "ClusterName", var.cluster_name, "ServiceName", var.web_service_name, { label = "Web", color = "#2196F3" }],
            ["AWS/ECS", "CPUUtilization", "ClusterName", var.cluster_name, "ServiceName", var.api_service_name, { label = "API", color = "#4CAF50" }]
          ]
          annotations = {
            horizontal = [{ value = 80, label = "Alert threshold", color = "#FF5722" }]
          }
          view   = "timeSeries"
          stat   = "Average"
          period = 60
          yAxis  = { left = { min = 0, max = 100 } }
        }
      },
      # Row 1: ECS Memory utilization
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "ECS Memory Utilization (%)"
          region = var.region
          metrics = [
            ["AWS/ECS", "MemoryUtilization", "ClusterName", var.cluster_name, "ServiceName", var.web_service_name, { label = "Web", color = "#2196F3" }],
            ["AWS/ECS", "MemoryUtilization", "ClusterName", var.cluster_name, "ServiceName", var.api_service_name, { label = "API", color = "#4CAF50" }]
          ]
          annotations = {
            horizontal = [{ value = 85, label = "Alert threshold", color = "#FF5722" }]
          }
          view   = "timeSeries"
          stat   = "Average"
          period = 60
          yAxis  = { left = { min = 0, max = 100 } }
        }
      },
      # Row 2: Running task count
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          title  = "ECS Running Task Count"
          region = var.region
          metrics = [
            ["ECS/ContainerInsights", "RunningTaskCount", "ClusterName", var.cluster_name, "ServiceName", var.web_service_name, { label = "Web", color = "#2196F3" }],
            ["ECS/ContainerInsights", "RunningTaskCount", "ClusterName", var.cluster_name, "ServiceName", var.api_service_name, { label = "API", color = "#4CAF50" }]
          ]
          annotations = {
            horizontal = [{ value = var.min_task_count, label = "Min tasks", color = "#FF9800" }]
          }
          view   = "timeSeries"
          stat   = "Average"
          period = 60
        }
      },
      # Row 2: ALB request count
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          title  = "ALB Request Count"
          region = var.region
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", var.alb_arn_suffix, { label = "Total requests", color = "#9C27B0" }]
          ]
          view   = "timeSeries"
          stat   = "Sum"
          period = 60
        }
      },
      # Row 3: ALB response time + unhealthy targets
      {
        type   = "metric"
        x      = 0
        y      = 12
        width  = 12
        height = 6
        properties = {
          title  = "ALB Response Time (p99)"
          region = var.region
          metrics = [
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", var.alb_arn_suffix, { label = "p99 latency", color = "#FF9800" }]
          ]
          view   = "timeSeries"
          stat   = "p99"
          period = 60
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 12
        width  = 12
        height = 6
        properties = {
          title  = "ALB Unhealthy Targets"
          region = var.region
          metrics = [
            ["AWS/ApplicationELB", "UnHealthyHostCount", "LoadBalancer", var.alb_arn_suffix, { label = "Unhealthy hosts", color = "#F44336" }]
          ]
          annotations = {
            horizontal = [{ value = 1, label = "Alert threshold", color = "#FF5722" }]
          }
          view   = "timeSeries"
          stat   = "Maximum"
          period = 60
        }
      }
    ]
  })
}
