[
  {
    "name": "minecraft-server",
    "image": "${container_image}",
    "essential": true,
    "portMappings": [
      {
        "containerPort": 25565,
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
        "awslogs-group": "/ecs/minecraft-server",
        "awslogs-region": "${aws_region}",
        "awslogs-stream-prefix": "ecs"
      }
    }
  }
]

