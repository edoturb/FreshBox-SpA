package terraform.policies.require_tags

import future.keywords.in

# IL2.1 - Politica de cumplimiento: todo recurso "taggeable" debe tener
# las etiquetas Environment y Owner. Esto asegura trazabilidad (buena
# practica de gobierno de nube exigida por estandares de la industria).

resources_needing_tags := {"aws_instance", "aws_vpc", "aws_security_group"}

deny[msg] {
  some address, rc in input.resource_changes
  rc.type in resources_needing_tags
  action := rc.change.actions
  action[_] != "delete"
  tags := object.get(rc.change.after, "tags", {})
  required := {"Environment", "Owner"}
  missing := required - {k | tags[k]}
  count(missing) > 0
  msg := sprintf("Recurso '%s' (%s) no tiene los tags obligatorios: %v", [address, rc.type, missing])
}
