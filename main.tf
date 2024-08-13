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


resource "docker_image" "nginx-proxy" {
  name         = var.nginx_proxy_docker_image
  keep_locally = true
}

resource "docker_image" "acme-companion" {
  name         = "nginxproxy/acme-companion"
  keep_locally = true
}

resource "docker_image" "ollama" {
  name         = var.ollama_docker_image
  keep_locally = true
}

resource "docker_image" "ollama-auth-provider" {
  name         = "deka-sqlite-auth-request"
  keep_locally = true
}

resource "docker_image" "nginx" {
  name         = "nginx:latest"
  keep_locally = true
}

resource "docker_image" "flowise" {
  name         = var.flowise_docker_image
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

# Network for authentication services
resource "docker_network" "tabby_auth_net" {
  name = "tabby_auth_net"
}

resource "docker_volume" "certs" {
  name = "certs"
}

resource "docker_volume" "vhost" {
  name = "vhost"
}

resource "docker_volume" "html" {
  name = "html"
}

resource "docker_volume" "acme" {
  name = "acme"
}

resource "docker_container" "https-reverse-proxy" {
  name    = "https-reverse-proxy"
  image   = docker_image.nginx-proxy.name
  restart = "always"

  networks_advanced {
    name = docker_network.tabby_front_net.name
  }

  ports {
    internal = 80
    external = 80
  }

  ports {
    internal = 443
    external = 443
  }

  volumes {
    host_path      = "/var/run/docker.sock"
    container_path = "/tmp/docker.sock"
    read_only      = true
  }

  volumes {
    volume_name    = docker_volume.certs.name
    container_path = "/etc/nginx/certs"
  }

  volumes {
    volume_name    = docker_volume.vhost.name
    container_path = "/etc/nginx/vhost.d"
  }

  volumes {
    volume_name    = docker_volume.html.name
    container_path = "/usr/share/nginx/html"
  }
  volumes {
    host_path      = abspath("${path.root}/nginx/nginx-proxy/body_size.conf")
    container_path = "/etc/nginx/conf.d/body_size.conf"
    read_only      = true
  }
}

resource "docker_container" "acme-companion" {
  name       = "nginx-proxy-acme"
  image      = docker_image.acme-companion.name
  depends_on = [docker_container.https-reverse-proxy]

  env = [
    "DEFAULT_EMAIL=${var.your_email}"
  ]

  volumes {
    from_container = docker_container.https-reverse-proxy.name
  }

  volumes {
    host_path      = "/var/run/docker.sock"
    container_path = "/var/run/docker.sock"
    read_only      = true
  }

  volumes {
    volume_name    = docker_volume.acme.name
    container_path = "/etc/acme.sh"
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
    "TABBY_WEBSERVER_JWT_TOKEN_SECRET=${var.tabby_jwt_token}",
    "TABBY_OLLAMA_ALLOW_PULL=y",
    "RUST_LOG=ollama_api_bindings=info",
    "VIRTUAL_HOST=tabby.${var.your_domain}",
    "LETSENCRYPT_HOST=tabby.${var.your_domain}",
    "VIRTUAL_PORT=8080"
  ]
  networks_advanced {
    name = docker_network.tabby_front_net.name
  }

  networks_advanced {
    name = docker_network.tabby_back_net.name
  }

}

resource "docker_container" "ollama" {
  name    = "ollama-tabby"
  restart = "always"
  image   = docker_image.ollama.name

  env = [
    "HSA_OVERRIDE_GFX_VERSION=10.3.0",
    "OLLAMA_DEBUG=0",
  ]

  volumes {
    host_path      = pathexpand("~/.ollama")
    container_path = "/root/.ollama"
  }

  networks_advanced {
    name = docker_network.tabby_back_net.name
  }

  ports {
    internal = 11434
    external = 11434
  }

  devices {
    host_path = "/dev/kfd"
  }

  devices {
    host_path = "/dev/dri"
  }
}

resource "docker_container" "flowise" {
  name    = "flowise"
  restart = "always"
  image   = docker_image.flowise.name

  env = [
    "VIRTUAL_HOST=flowise.${var.your_domain}",
    "LETSENCRYPT_HOST=flowise.${var.your_domain}",
    "VIRTUAL_PORT=3000",
    "FLOWISE_USERNAME=${var.flowise_user}",
    "FLOWISE_PASSWORD=${var.flowise_password}",
    "DATABASE_PATH=/root/.flowise"
  ]

  volumes {
    host_path      = pathexpand("~/.flowise")
    container_path = "/root/.flowise"
  }

  ports {
    internal = 3003
    external = 3003
  }

  networks_advanced {
    name = docker_network.tabby_front_net.name
  }

  networks_advanced {
    name = docker_network.tabby_back_net.name
  }
}

resource "docker_container" "ollama-auth-provider" {
  name    = "ollama-auth-provider"
  restart = "always"
  image   = docker_image.ollama-auth-provider.name

  env = [
    "DATABASE_LOCATION=/data/ee/db.sqlite"
  ]
  networks_advanced {
    name = docker_network.tabby_auth_net.name
  }

  volumes {
    host_path      = pathexpand("~/.tabby-ollama")
    container_path = "/data"
  }

}

resource "docker_container" "ollama-auth-proxy" {
  name    = "ollama-auth-proxy"
  restart = "always"
  image   = docker_image.nginx.name

  env = [
    "VIRTUAL_HOST=ollama.${var.your_domain}",
    "LETSENCRYPT_HOST=ollama.${var.your_domain}"
  ]

  volumes {
    host_path      = abspath("${path.root}/nginx/ollama/")
    container_path = "/etc/nginx/conf.d/"
  }


  networks_advanced {
    name = docker_network.tabby_front_net.name
  }

  networks_advanced {
    name = docker_network.tabby_auth_net.name
  }

  networks_advanced {
    name = docker_network.tabby_back_net.name
  }
}
