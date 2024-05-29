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

# Network connecting main https proxy with tabby
resource "docker_network" "tabby_front_net" {
  name = "tabby_front_net"
}

# Network for Tabby services: workers, http-api providers, etc
resource "docker_network" "tabby_back_net" {
  name = "tabby_back_net"
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
    "HSA_OVERRIDE_GFX_VERSION=10.3.0",
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
