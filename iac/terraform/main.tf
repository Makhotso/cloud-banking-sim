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
# Docker network for inter-container communication
# -------------------------
resource "docker_network" "cloud_network" {
  name = "cloud_network"
}

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

  # Attach container to cloud_network so other containers can resolve it by name
  networks_advanced {
    name = docker_network.cloud_network.name
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

  # Attach container to cloud_network so FastAPI can reach it by hostname
  networks_advanced {
    name = docker_network.cloud_network.name
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

  # Ensure FastAPI starts only after MongoDB and MinIO are ready
  depends_on = [
    docker_container.mongodb,
    docker_container.minio
  ]

  # Attach container to cloud_network so it can resolve MongoDB and MinIO by hostname
  networks_advanced {
    name = docker_network.cloud_network.name
  }
}
