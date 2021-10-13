output "ingress_host" {
  description = "The ingress host for the ascent ui instance"
  value       = local.ingress_host
  depends_on  = [helm_release.ascent_ui]
}
