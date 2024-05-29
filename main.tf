terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0.1"
    }
  }
}

provider "docker" {}

# Images
resource "docker_image" "tabby" {
  name         = var.tabby_docker_image
  keep_locally = true
}

resource "docker_image" "certbot" {
  name         = "certbot/certbot:latest"
  keep_locally = true
}

resource "docker_image" "nginx" {
  name         = "nginx:latest"
  keep_locally = true
}

resource "docker_image" "tabby-worker-manager" {
  name         = "tabby-worker-manager"
  keep_locally = true
}

resource "docker_image" "ollama" {
  name         = var.ollama_docker_image
  keep_locally = true
}



# Network connecting main https proxy with tabby
resource "docker_network" "tabby_front_net" {
  name = "tabby_front_net"
}

# Network for Tabby services: workers, http-api providers, etc
resource "docker_network" "tabby_back_net" {
  name = "tabby_back_net"
}

resource "docker_container" "https-reverse-proxy" {
  name       = "https-reverse-proxy"
  image      = docker_image.nginx.image_id
  restart    = "always"
  depends_on = [docker_container.tabby-web, docker_container.tabby-manager-api]

  networks_advanced {
    name = docker_network.tabby_front_net.name
  }

  volumes {
    host_path      = abspath("${path.root}/nginx/conf")
    container_path = "/etc/nginx/conf.d"
  }

  volumes {
    host_path      = abspath("${path.root}/certbot/www")
    container_path = "/var/www/certbot"
  }

  volumes {
    host_path      = abspath("${path.root}/certbot/conf")
    container_path = "/etc/letsencrypt"
  }

  ports {
    internal = 80
    external = 80
  }

  ports {
    internal = 443
    external = 443
  }
}

resource "docker_container" "certbot" {
  name  = "certbot"
  image = docker_image.certbot.image_id

  volumes {
    host_path      = abspath("${path.root}/certbot/www")
    container_path = "/var/www/certbot"
  }

  volumes {
    host_path      = abspath("${path.root}/certbot/conf")
    container_path = "/etc/letsencrypt"
  }
}

resource "docker_container" "tabby-web" {
  name       = "tabby-web"
  image      = docker_image.tabby.name
  entrypoint = ["tabby"]
  command = [
    "serve"
  ]
  restart    = "always"
  depends_on = [docker_container.ollama]
  volumes {
    host_path      = pathexpand("~/.tabby-ollama")
    container_path = "/data"
  }
  env = [
    "HSA_OVERRIDE_GFX_VERSION=10.3.0",
    "TABBY_OLLAMA_ALLOW_PULL=y",
    "RUST_LOG=ollama_api_bindings=info"
  ]
  networks_advanced {
    name = docker_network.tabby_front_net.name
  }

  networks_advanced {
    name = docker_network.tabby_back_net.name
  }

}

resource "docker_container" "tabby-manager-api" {
  name    = "tabby-manager-api"
  restart = "always"
  image   = docker_image.tabby-worker-manager.name
  command = [
    "--key",
    "${var.tabby_worker_token}"
  ]
  volumes {
    host_path      = "/var/run/docker.sock"
    container_path = "/var/run/docker.sock"
  }

  networks_advanced {
    name = docker_network.tabby_front_net.name
  }
}

resource "docker_container" "ollama" {
  name    = "ollama-tabby"
  restart = "always"
  image   = docker_image.ollama.name

  env = [
    "HSA_OVERRIDE_GFX_VERSION=10.3.0",
  ]

  volumes {
    host_path      = pathexpand("~/.ollama")
    container_path = "/root/.ollama"
  }

  networks_advanced {
    name = docker_network.tabby_back_net.name
  }

  devices {
    host_path = "/dev/kfd"
  }

  devices {
    host_path = "/dev/dri"
  }
}
