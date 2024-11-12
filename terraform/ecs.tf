# Define the ECS cluster
resource "aws_ecs_cluster" "app_cluster" {
  name = "app-cluster"
}

# Define the IAM role for ECS task execution
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Effect = "Allow"
      },
    ]
  })
}

# Attach necessary policies to the role
resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ECS Task Definition using DockerHub image
resource "aws_ecs_task_definition" "app_task" {
  family                   = "app-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256" # Adjust based on app needs
  memory                   = "512" # Adjust based on app needs
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "app-container"
      image     = "pbell37/poc-aws-sftp:latest" # Update with actual DockerHub image
      cpu       = 256
      memory    = 512
      essential = true
      portMappings = [
        {
          containerPort = 3000
          hostPort      = 3000
          protocol      = "tcp"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.ecs_log_group.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
        }
      }
      environment = [
        {
          name  = "AWS_REGION"
          value = "${var.aws_region}"
        },
        {
          name  = "AWS_ACCESS_KEY_ID"
          value = "${var.aws_access_key_id}"
        },
        {
          name  = "AWS_SECRET_ACCESS_KEY"
          value = "${var.aws_secret_access_key}"
        },
        { name = "BUCKET_NAME", value = "${aws_s3_bucket.sftp_destination_bucket.bucket}" },
        { name = "AWS_REGION", value = "${var.aws_region}" },
        { name = "S3_EVENT_QUEUE_URL", value = "${aws_sqs_queue.s3_event_queue.id}" },

      ]
    }
  ])
}

# ECS Service to run the task definition
resource "aws_ecs_service" "app_service" {
  name            = "app-service"
  cluster         = aws_ecs_cluster.app_cluster.id
  task_definition = aws_ecs_task_definition.app_task.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [aws_subnet.public_subnet.id]
    security_groups  = [aws_security_group.ecs_security_group.id]
    assign_public_ip = true
  }

  depends_on = [
    aws_ecs_task_definition.app_task
  ]
}
