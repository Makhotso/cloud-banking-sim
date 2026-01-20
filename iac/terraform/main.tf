terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

provider "docker" {}

# MongoDB container
resource "docker_container" "mongodb" {
  name  = "mongodb"
  image = "mongo:6"
  ports {
    internal = 27017
    external = 27017
  }
}

# MinIO container
resource "docker_container" "minio" {
  name    = "minio"
  image   = "minio/minio"
  command = "server /data --console-address ':9001'"
  env = [
    "MINIO_ROOT_USER=admin",
    "MINIO_ROOT_PASSWORD=admin123"
  ]
  ports {
    internal = 9000
    external = 9000
  }
  ports {
    internal = 9001
    external = 9001
  }
}

# FastAPI container
resource "docker_image" "fastapi" {
  name = "fastapi"
  build {
    context = "${path.module}/../../fastapi"
  }
}

resource "docker_container" "fastapi" {
  name  = "fastapi"
  image = docker_image.fastapi.latest
  ports {
    internal = 8000
    external = 8000
  }
  depends_on = [
    docker_container.mongodb,
    docker_container.minio
  ]
}
