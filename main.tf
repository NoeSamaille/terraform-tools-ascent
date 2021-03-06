# resource "null_resource" "print_vars" {
#   provisioner "local-exec" {
#     command = <<EOT
#       cat <<EOF
#       mode = ${var.mode}
#       cluster_name = ${var.cluster_name}
#       cluster_type = ${var.cluster_type}
#       cluster_config_file = ${var.cluster_config_file}
#       releases_namespace = ${var.releases_namespace}
#       cluster_ingress_hostname = ${var.cluster_ingress_hostname}
#       tls_secret_name = ${var.tls_secret_name}
#       gitops_dir = ${var.gitops_dir}
#       releases_namespace = ${var.releases_namespace}
#       cos_instance_id = ${var.cos_instance_id}
#       cos_bucket_cross_region_location = ${var.cos_bucket_cross_region_location}
#       cos_bucket_storage_class = ${var.cos_bucket_storage_class}
#       cos_bucket_storage_class = ${var.cos_bucket_storage_class}
#       EOF
#     EOT
#   }
# }


data "external" "mongo_root_password" {
  program = ["${path.module}/token.sh"]
}
data "external" "mongo_password" {
  program = ["${path.module}/token.sh"]
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
  injector_name   = "ascent-injector"
  chart_name_mongo   = "ascent-mongodb"
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
      enabled = local.cluster_type == "openshift" ? true : false
    }
    ingress = {
      enabled = local.cluster_type == "openshift" ? false : true
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
    connectsTo = local.chart_name_mongo
    runtime = ""
  }
  ascent_ui_config = {
    tlsSecretName = var.tls_secret_name
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
      enabled = local.cluster_type == "openshift" ? true : false
    }
    ingress = {
      enabled = local.cluster_type == "openshift" ? false : true
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
    connectsTo = local.chart_name_bff
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
  program = ["${path.module}/token.sh"]
}
resource "null_resource" "setup_oauth_client" {
  provisioner "local-exec" {
    command = <<EOT
      cat <<EOF | kubectl apply -f -
apiVersion: oauth.openshift.io/v1
grantMethod: auto
kind: OAuthClient
metadata:
  namespace: ${var.releases_namespace}
  name: ascent
  selfLink: /apis/oauth.openshift.io/v1/oauthclients/ascent
redirectURIs:
- ${local.endpoint_url}/login/callback
secret: ${data.external.oauth_client_secret.result.token}
EOF
    EOT

    environment = {
      KUBECONFIG = var.cluster_config_file
    }
  }
}
resource "null_resource" "create_oauth_secret" {
  provisioner "local-exec" {
    command = <<EOT
      oc create secret generic ascent-oauth-config --from-literal=api-url=$(oc whoami --show-server) --from-literal=oauth-config="{\"clientID\": \"ascent\", \"clientSecret\": \"${data.external.oauth_client_secret.result.token}\", \"api_endpoint\": \"$(oc whoami --show-server)\"}" -n ${var.releases_namespace}
    EOT

    environment = {
      KUBECONFIG = var.cluster_config_file
    }
  }
}
resource "null_resource" "create_mongo_secret" {
  provisioner "local-exec" {
    command = <<EOT
      kubectl create secret generic ascent-mongo-config --from-literal=binding="{\"connection\":{\"mongodb\":{\"composed\":[\"mongodb://ascent-admin:${data.external.mongo_password.result.token}@ascent-mongodb:27017/ascent-db\"],\"authentication\":{\"username\":\"ascent-admin\",\"password\":\"${data.external.mongo_password.result.token}\"},\"database\":\"ascent-db\",\"hosts\":[{\"hostname\":\"localhost\",\"port\":27017}]}}}" -n ${var.releases_namespace}
    EOT

    environment = {
      KUBECONFIG = var.cluster_config_file
    }
  }
}
data "external" "instance_id" {
  program = ["${path.module}/token.sh"]
}
resource "null_resource" "create_ascent_cm" {
  provisioner "local-exec" {
    command = <<EOT
      kubectl create configmap ascent --from-literal=route="${local.endpoint_url}" --from-literal=api-host="http://${local.chart_name_bff}" --from-literal=instance-id=${data.external.instance_id.result.token} -n ${var.releases_namespace}
    EOT

    environment = {
      KUBECONFIG = var.cluster_config_file
    }
  }
}

# Create Bucket and bind COS to cluster
resource "ibm_cos_bucket" "ascent-bucket" {
  bucket_name          = "ascent-storage-${data.external.instance_id.result.token}"
  resource_instance_id = var.cos_instance_id
  region_location      = var.cos_bucket_cross_region_location
  storage_class        = var.cos_bucket_storage_class
}
resource "ibm_container_bind_service" "bind_service" {
  cluster_name_id       = var.cluster_name
  service_instance_name = var.cos_instance_name
  namespace_id          = var.releases_namespace
}
resource "null_resource" "create_cos_secret" {
  depends_on = [ibm_container_bind_service.bind_service]
  provisioner "local-exec" {
    command = <<EOT
      kubectl get secret binding-${var.cos_instance_name} -n ${var.releases_namespace} -o yaml | sed "s/binding-${var.cos_instance_name}/ascent-cos-config/g" | kubectl create -f -
    EOT

    environment = {
      KUBECONFIG = var.cluster_config_file
    }
  }
}
resource "null_resource" "edit_cos_secret" {
  depends_on = [null_resource.create_cos_secret]
  provisioner "local-exec" {
    command = <<EOT
      BINDING=$(kubectl get secret ascent-cos-config -n ${var.releases_namespace} -o json | jq '.data["binding"]' | sed "s/\"//g") && kubectl get secret ascent-cos-config -n ${var.releases_namespace} -o json | jq --arg binding "$(echo $BINDING | base64 -d | sed "s/https:\/\/control.cloud-object-storage.cloud.ibm.com\/v2\/endpoints/s3.eu.cloud-object-storage.appdomain.cloud/g" | base64)" '.data["binding"]=$binding' | kubectl apply -f -
    EOT

    environment = {
      KUBECONFIG = var.cluster_config_file
    }
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
    partOf = "ascent"
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
  depends_on = [
    null_resource.create_mongo_secret,
    local_file.values_mongo
  ]
  count = var.mode != "setup" ? 1 : 0

  name         = local.chart_name_mongo
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
  depends_on = [
    null_resource.create_oauth_secret,
    null_resource.create_mongo_secret,
    null_resource.edit_cos_secret,
    null_resource.create_ascent_cm,
    helm_release.ascent_mongo,
    local_file.values_bff
  ]
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
  depends_on = [
    null_resource.create_oauth_secret,
    null_resource.create_ascent_cm,
    helm_release.ascent_bff,
    local_file.values_ui
  ]
  count = var.mode != "setup" ? 1 : 0

  name         = local.chart_name_ui
  chart        = local.chart_dir_ui
  namespace    = var.releases_namespace
  force_update = true
  replace      = true
}

# Set up Ascent Injector
resource "null_resource" "ascent_injector" {
  depends_on = [
    helm_release.ascent_bff
  ]

  provisioner "local-exec" {
    command = <<EOT
      cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: ${local.injector_name}
  namespace: ${var.releases_namespace}
spec:
  containers:
  - name: ${local.injector_name}
    image: quay.io/noesamaille0/ascent-injector:0.0.2
    imagePullPolicy: IfNotPresent
    env:
      - name: MONGO_CONFIG
        valueFrom:
          secretKeyRef:
            name: ascent-mongo-config
            key: binding
      - name: COS_CONFIG
        valueFrom:
          secretKeyRef:
            name: ascent-cos-config
            key: binding
      - name: INSTANCE_ID
        valueFrom:
          configMapKeyRef:
            name: ascent
            key: instance-id
  restartPolicy: OnFailure
  serviceAccountName: default
EOF
    EOT

    environment = {
      KUBECONFIG = var.cluster_config_file
    }
  }
}