provider "aws" {
  region = var.region
}

provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

resource "aws_ecs_cluster" "mountain_race" {
  name = "mountain-race"
  tags = { Name = "mountain-race" }
}

resource "aws_cloudwatch_log_group" "mountain_race" {
  name              = "/ecs/mountain-race"
  retention_in_days = 7
  tags              = { Name = "mountain-race" }
}

resource "aws_security_group" "mountain_race" {
  name        = "mountain-race-ecs"
  description = "ECS task security group for mountain-race"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 8003
    to_port     = 8003
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "mountain-race-ecs" }
}

resource "aws_ecs_task_definition" "mountain_race" {
  family                   = "mountain-race"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([{
    name      = "app"
    image     = "${aws_ecr_repository.mountain_race.repository_url}:latest"
    essential = true

    portMappings = [{
      containerPort = 8003
      protocol      = "tcp"
    }]

    environment = [
      { name = "APP_ENV", value = "production" }
    ]

    secrets = [
      { name = "OPENAI_API_KEY", valueFrom = aws_ssm_parameter.openai_api_key.arn },
      { name = "LLM_PROVIDER", valueFrom = aws_ssm_parameter.llm_provider.arn },
      { name = "METEOFRANCE_USER", valueFrom = aws_ssm_parameter.meteo_france_user.arn },
      { name = "METEOFRANCE_PASS", valueFrom = aws_ssm_parameter.meteo_france_password.arn }
    ]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.mountain_race.name
        "awslogs-region"        = var.region
        "awslogs-stream-prefix" = "app"
      }
    }
  }])

  tags = { Name = "mountain-race" }
}

resource "aws_ecs_service" "mountain_race" {
  name            = "mountain-race"
  cluster         = aws_ecs_cluster.mountain_race.id
  task_definition = aws_ecs_task_definition.mountain_race.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = data.aws_subnets.default.ids
    security_groups  = [aws_security_group.mountain_race.id]
    assign_public_ip = true
  }

  lifecycle {
    ignore_changes = [desired_count]
  }

  tags = { Name = "mountain-race" }
}

resource "aws_appautoscaling_target" "mountain_race" {
  max_capacity       = 1
  min_capacity       = 0
  resource_id        = "service/${aws_ecs_cluster.mountain_race.name}/${aws_ecs_service.mountain_race.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

# Scale to 0 at 21:00 UTC (23:00 Paris CEST / 22:00 CET)
resource "aws_appautoscaling_scheduled_action" "scale_down" {
  name               = "mountain-race-scale-down"
  service_namespace  = "ecs"
  resource_id        = aws_appautoscaling_target.mountain_race.resource_id
  scalable_dimension = aws_appautoscaling_target.mountain_race.scalable_dimension
  schedule           = "cron(0 21 * * ? *)"

  scalable_target_action {
    min_capacity = 0
    max_capacity = 0
  }
}

# Scale to 1 at 06:00 UTC (08:00 Paris CEST / 07:00 CET)
resource "aws_appautoscaling_scheduled_action" "scale_up" {
  name               = "mountain-race-scale-up"
  service_namespace  = "ecs"
  resource_id        = aws_appautoscaling_target.mountain_race.resource_id
  scalable_dimension = aws_appautoscaling_target.mountain_race.scalable_dimension
  schedule           = "cron(0 6 * * ? *)"

  scalable_target_action {
    min_capacity = 1
    max_capacity = 1
  }
}

output "ecs_cluster_name" { value = aws_ecs_cluster.mountain_race.name }
output "ecs_service_name" { value = aws_ecs_service.mountain_race.name }
