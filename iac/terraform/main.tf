terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

provider "docker" {}

# -------------------------
# MongoDB container
# -------------------------
resource "docker_container" "mongodb" {
  name     = "mongodb"
  image    = "mongo:6"
  restart  = "always"
  must_run = true

  ports {
    internal = 27017
    external = 27017
  }
}

# -------------------------
# MinIO container
# -------------------------
resource "docker_container" "minio" {
  name     = "minio"
  image    = "minio/minio"
  restart  = "always"
  must_run = true

  command = ["server", "/data", "--console-address", ":9001"]

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

# -------------------------
# FastAPI image build
# -------------------------
resource "docker_image" "fastapi" {
  name = "cloud-banking-fastapi"

  build {
    context = "${path.module}/../../fastapi"
  }
}

# -------------------------
# FastAPI container
# -------------------------
# FastAPI container
resource "docker_container" "fastapi" {
  name      = "fastapi"
  image     = docker_image.fastapi.image_id
  restart   = "always"
  must_run  = true

  command = [
    "uvicorn",
    "main:app",
    "--host",
    "0.0.0.0",
    "--port",
    "8000"
  ]

  env = [
    "MONGO_URI=mongodb://mongodb:27017",
    "MINIO_ENDPOINT=minio:9000",
    "MINIO_ACCESS_KEY=admin",
    "MINIO_SECRET_KEY=admin123"
  ]

  ports {
    internal = 8000
    external = 8000
  }

  depends_on = [
    docker_container.mongodb,
    docker_container.minio
  ]
}