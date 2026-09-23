


locals {
  app_options = {
    webgoat = {
      deploy_type       = "docker_run"
      docker_image      = "webgoat/webgoat"
      container_port    = 8080
      git_repo          = ""
      health_check_path = "/WebGoat/login"
      host_port         = 80
      instance_type     = "t3.small"
    }
    dvwa = {
      deploy_type       = "docker_run"
      docker_image      = "vulnerables/web-dvwa"
      container_port    = 80
      git_repo          = ""
      health_check_path = "/"
      host_port         = 80
      instance_type     = "t2.micro"
    }
    bwapp = {
      deploy_type       = "docker_run"
      docker_image      = "raesene/bwapp"
      container_port    = 80
      git_repo          = ""
      health_check_path = "/"
      host_port         = 80
      instance_type     = "t2.micro"
    }
    juice_shop = {
      deploy_type       = "docker_run"
      docker_image      = "bkimminich/juice-shop"
      container_port    = 3000
      git_repo          = ""
      health_check_path = "/"
      host_port         = 80
      instance_type     = "t2.micro"
    }
    mutillidae = {
      deploy_type       = "docker_run"
      docker_image      = "citizenstig/nowasp"
      container_port    = 80
      git_repo          = ""
      health_check_path = "/"
      host_port         = 80
      instance_type     = "t3.small"
    }
    vuln_bank = {
      deploy_type       = "compose"
      docker_image      = ""
      container_port    = 5000
      git_repo          = "https://github.com/Commando-X/vuln-bank.git"
      health_check_path = "/"
      host_port         = 80
      instance_type     = "t2.micro"
    }
    altoroj = {
      deploy_type       = "docker_run"
      docker_image      = "jasonhubs/altoroj:3.1.1"
      container_port    = 8080
      git_repo          = ""
      health_check_path = "/altoroj/"
      host_port         = 80
      instance_type     = "t2.micro"
    }
  }

  selected_app = local.app_options[var.target_app]

  user_data_rendered = templatefile("${path.module}/templates/userdata.sh.tpl", {
    deploy_type    = local.selected_app.deploy_type
    docker_image   = local.selected_app.docker_image
    container_port = local.selected_app.container_port
    git_repo       = local.selected_app.git_repo
    instance_type  = local.selected_app.instance_type
  })

  app_host_port = 80
}