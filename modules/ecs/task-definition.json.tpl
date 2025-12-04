[
  {
    "name": "${container_name}",
    "image": "${container_image}",
    "essential": true,
    "portMappings": [
      {
        "containerPort": ${minecraft_port},
        "protocol": "tcp"
      }
    ],
    "mountPoints": [
      {
        "sourceVolume": "efs-storage",
        "containerPath": "/data"
      }
    ],
    "environment": [
      {
        "name": "EULA",
        "value": "TRUE"
      },
      {
        "name": "REDIS_HOST",
        "value": "${redis_host}"
      },
      {
        "name": "REDIS_PORT",
        "value": "${redis_port}"
      }
    ],
    "secrets": [
      {
        "name": "REDIS_AUTH",
        "valueFrom": "${redis_auth_secret_arn}"
      }
    ],
    "logConfiguration": {
      "logDriver": "awslogs",
      "options": {
        "awslogs-group": "${log_group_name}",
        "awslogs-region": "${aws_region}",
        "awslogs-stream-prefix": "ecs"
      }
    }
  }
]


