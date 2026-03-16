# Terraform Security Group Rules — Cross-Module References

## Pattern

Never define ingress or egress rules inside an `aws_security_group` resource that reference a security group from another module. Always define cross-module rules as standalone `aws_security_group_rule` resources in the root module.

## Why This Matters

When a security group ID is passed between modules as a variable (a plain string), Terraform's dependency graph has no edge between the two security group resources. During `terraform destroy`, Terraform cannot determine the correct deletion order and attempts to delete both SGs in parallel. AWS rejects the deletion with `DependencyViolation` because the rule still exists.

`aws_security_group_rule` resources in the root module reference both SG IDs as `module.x.sg_id` — real resource references. Terraform sees the dependency edge and deletes the rule before either SG.

## What Not To Do

```hcl
# modules/ecs/main.tf — WRONG
resource "aws_security_group" "ecs_tasks" {
  ingress {
    from_port       = 3300
    security_groups = [var.alb_security_group_id]  # opaque string — no graph edge
  }
}
```

```hcl
# modules/rds/main.tf — WRONG
resource "aws_security_group" "rds" {
  ingress {
    from_port       = 5432
    security_groups = [var.ecs_tasks_security_group_id]  # opaque string — no graph edge
  }
}
```

## Correct Approach

Each module owns its SG with no cross-module ingress/egress rules:

```hcl
# modules/ecs/main.tf — CORRECT
resource "aws_security_group" "ecs_tasks" {
  # No inline cross-module ingress rules.
  # Rules referencing other modules' SGs are in infra/main.tf.
  egress { ... }
}
```

Cross-module rules are defined at root where both resource references exist:

```hcl
# infra/main.tf — CORRECT
resource "aws_security_group_rule" "alb_to_ecs_web" {
  type                     = "ingress"
  from_port                = 3300
  to_port                  = 3300
  protocol                 = "tcp"
  source_security_group_id = module.alb.alb_security_group_id   # real reference
  security_group_id        = module.ecs.ecs_tasks_security_group_id  # real reference
}
```

## Checklist

- [ ] Each module's `aws_security_group` has only CIDR-based ingress/egress rules
- [ ] Any rule that references an SG from another module is an `aws_security_group_rule` in root
- [ ] The referenced SG IDs come from module outputs (not variables) in the root rule
- [ ] No `var.*_security_group_id` is passed into a module solely to be used in an inline ingress block
