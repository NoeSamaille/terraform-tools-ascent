data "external" "mongo_root_password" {
  program = ["node", "${path.module}/token.js"]
}
data "external" "mongo_password" {
  program = ["node", "${path.module}/token.js"]
}
locals {
  cluster_type = var.cluster_type == "kubernetes" ? "kubernetes" : "openshift"
  ingress_host = "ascent-ui-${var.releases_namespace}.${var.cluster_ingress_hostname}"
  endpoint_url = "http${var.tls_secret_name != "" ? "s" : ""}://${local.ingress_host}"
  gitops_dir   = var.gitops_dir != "" ? var.gitops_dir : "${path.cwd}/gitops"
  chart_name_bff   = "ascent-bff"
  chart_dir_bff    = "${local.gitops_dir}/${local.chart_name_bff}"
  chart_name_ui   = "ascent-ui"
  chart_dir_ui    = "${local.gitops_dir}/${local.chart_name_ui}"
  chart_name_mongo   = "mongodb"
  chart_dir_mongo    = "${local.gitops_dir}/${local.chart_name_mongo}"
  global = {
    ingressSubdomain = var.cluster_ingress_hostname
    clusterType = var.cluster_type
  }
  ascent_bff_config = {
    global = local.global
    replicaCount = 1
    logLevel = "debug"
    image = {
      repository = "quay.io/noesamaille0/ascent-bff"
      tag = "0.0.1"
      pullPolicy = "IfNotPresent"
      port = 3001
    }
    nameOverride = ""
    fullnameOverride = ""
    service = {
      type = "ClusterIP"
      port = 80
    }
    route = {
      enabled = false
    }
    ingress = {
      enabled = true
      appid = {
        enabled = false
        requestType = "web"
      }
      namespaceInHost = true
      subdomain = "containers.appdomain.cloud"
      path = "/"
    }
    vcsInfo = {
      repoUrl = ""
      branch = ""
    }
    authentication = {
      provider = "openshift"
    }
    partOf = "ascent"
    connectsTo = ""
    runtime = ""
  }
  ascent_ui_config = {
    global = local.global
    replicaCount = 1
    logLevel = "debug"
    image = {
      repository = "quay.io/noesamaille0/ascent-ui"
      tag = "0.0.1"
      pullPolicy = "IfNotPresent"
      port = 3000
    }
    nameOverride = ""
    fullnameOverride = ""
    service = {
      type = "ClusterIP"
      port = 80
    }
    route = {
      enabled = false
    }
    ingress = {
      enabled = true
      appid = {
        enabled = false
        requestType = "web"
      }
      namespaceInHost = true
      subdomain = "containers.appdomain.cloud"
      path = "/"
    }
    vcsInfo = {
      repoUrl = ""
      branch = ""
    }
    authentication = {
      provider = "openshift"
    }
    partOf = "ascent"
    connectsTo = "ascent-bff"
    runtime = "js"
  }
  mongodb_config = {
    image = {
      registry = "docker.io"
      repository = "bitnami/mongodb"
      tag = "4.4.9-debian-10-r0"
      pullPolicy = "IfNotPresent"
    }

    auth = {
      enabled = true
      rootUser = "root"
      rootPassword = data.external.mongo_root_password.result.token
      username = "ascent-admin"
      password = data.external.mongo_password.result.token
      database = "ascent-db"
    }

    podSecurityContext = {
      enabled = false
    }

    containerSecurityContext = {
      enabled = false
    }

    persistence = {
      enabled = true
      size = "10Gi"
      mountPath = "/bitnami/mongodb"
    }
  }
}

resource "null_resource" "delete_consolelink" {
  count = var.cluster_type != "kubernetes" ? 1 : 0

  provisioner "local-exec" {
    command = "kubectl delete consolelink -l grouping=garage-cloud-native-toolkit -l app=${local.chart_name_ui} || exit 0"

    environment = {
      KUBECONFIG = var.cluster_config_file
    }
  }
}

# Create K8s OAuthClient, secrets and configmaps required by ascent charts
data "external" "oauth_client_secret" {
  program = ["node", "${path.module}/token.js"]
}
resource "null_resource" "setup_oauth_client" {
  provisioner "local-exec" {
    command = <<EOT
      cat <<EOF | kubectl apply -f -
apiVersion: oauth.openshift.io/v1
grantMethod: auto
kind: OAuthClient
metadata:
name: ascent
selfLink: /apis/oauth.openshift.io/v1/oauthclients/ascent
redirectURIs:
- ${local.endpoint_url}/login/callback
secret: ${data.external.oauth_client_secret.result.token}
EOF
    EOT
  }

  environment = {
    KUBECONFIG = var.cluster_config_file
  }
}
resource "null_resource" "create_oauth_secret" {
  provisioner "local-exec" {
    command = <<EOT
      oc create secret generic ascent-oauth-config --from-literal=api-url=$(oc whoami --show-server) --from-literal=oauth-config="{\"clientID\": \"ascent\", \"clientSecret\": \"${data.external.oauth_client_secret.result.token}\", \"api_endpoint\": \"$(oc whoami --show-server)\"}" -n ${var.releases_namespace}
    EOT
  }

  environment = {
    KUBECONFIG = var.cluster_config_file
  }
}
resource "null_resource" "create_mongo_secret" {
  provisioner "local-exec" {
    command = <<EOT
      kubectl create secret generic ascent-mongo-config --from-literal=binding="{\"connection\":{\"mongodb\":{\"composed\":[\"mongodb://ascent-admin:${data.external.mongo_password.result.token}@ascent-mongodb:27017/ascent-db\"],\"authentication\":{\"username\":\"ascent-admin\",\"password\":\"${data.external.mongo_password.result.token}\"},\"database\":\"ascent-db\",\"hosts\":[{\"hostname\":\"localhost\",\"port\":27017}]}}}" -n ${var.releases_namespace}
    EOT
  }

  environment = {
    KUBECONFIG = var.cluster_config_file
  }
}
data "external" "instance_id" {
  program = ["node", "${path.module}/token.js"]
}
resource "null_resource" "create_ascent_cm" {
  provisioner "local-exec" {
    command = <<EOT
      kubectl create configmap ascent --from-literal=route="${local.endpoint_url}" --from-literal=api-host="http://${local.chart_name_bff}" --from-literal=instance-id=${data.external.instance_id.result}
    EOT
  }

  environment = {
    KUBECONFIG = var.cluster_config_file
  }
}

# Set up MongoDB chart
resource "null_resource" "setup_chart_mongo" {
  provisioner "local-exec" {
    command = "mkdir -p ${local.chart_dir_mongo} && cp -R ${path.module}/chart/${local.chart_name_mongo}/* ${local.chart_dir_mongo}"
  }
}
resource "local_file" "values_mongo" {
  depends_on = [null_resource.setup_chart_mongo, null_resource.delete_consolelink]

  content  = yamlencode({
    global = local.global
    mongodb = local.mongodb_config
  })
  filename = "${local.chart_dir_mongo}/values.yaml"
}
resource "null_resource" "print_values_mongo" {
  depends_on = [local_file.values_mongo]
  provisioner "local-exec" {
    command = "cat ${local_file.values_mongo.filename}"
  }
}
resource "helm_release" "ascent_mongo" {
  depends_on = [null_resource.setup_mongo_secret, local_file.values_mongo]
  count = var.mode != "setup" ? 1 : 0

  name         = "ascent-mongodb"
  chart        = local.chart_dir_mongo
  namespace    = var.releases_namespace
  force_update = true
  replace      = true
}

# Set up Ascent BFF chart
resource "null_resource" "setup_chart_bff" {
  provisioner "local-exec" {
    command = "mkdir -p ${local.chart_dir_bff} && cp -R ${path.module}/chart/${local.chart_name_bff}/* ${local.chart_dir_bff}"
  }
}
resource "local_file" "values_bff" {
  depends_on = [null_resource.setup_chart_bff, null_resource.delete_consolelink]

  content  = yamlencode(local.ascent_bff_config)
  filename = "${local.chart_dir_bff}/values.yaml"
}
resource "null_resource" "print_values_bff" {
  depends_on = [local_file.values_bff]
  provisioner "local-exec" {
    command = "cat ${local_file.values_bff.filename}"
  }
}
resource "helm_release" "ascent_bff" {
  depends_on = [local_file.values_bff]
  count = var.mode != "setup" ? 1 : 0

  name         = local.chart_name_bff
  chart        = local.chart_dir_bff
  namespace    = var.releases_namespace
  force_update = true
  replace      = true
}

# Set up Ascent UI chart
resource "null_resource" "setup_chart_ui" {
  provisioner "local-exec" {
    command = "mkdir -p ${local.chart_dir_ui} && cp -R ${path.module}/chart/${local.chart_name_ui}/* ${local.chart_dir_ui}"
  }
}
resource "local_file" "values_ui" {
  depends_on = [null_resource.setup_chart_ui, null_resource.delete_consolelink]

  content  = yamlencode(local.ascent_ui_config)
  filename = "${local.chart_dir_ui}/values.yaml"
}
resource "null_resource" "print_values_ui" {
  depends_on = [local_file.values_ui]
  provisioner "local-exec" {
    command = "cat ${local_file.values_ui.filename}"
  }
}
resource "helm_release" "ascent_ui" {
  depends_on = [local_file.values_ui]
  count = var.mode != "setup" ? 1 : 0

  name         = local.chart_name_ui
  chart        = local.chart_dir_ui
  namespace    = var.releases_namespace
  force_update = true
  replace      = true
}