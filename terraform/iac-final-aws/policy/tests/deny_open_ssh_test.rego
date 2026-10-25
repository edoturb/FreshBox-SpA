package terraform.policies.deny_open_ssh

# IL2.3 - Prueba que valida que la politica efectivamente detecta un
# security group mal configurado (SSH abierto a todo internet).
test_deny_ssh_open_to_world {
  count(deny) > 0 with input as {
    "resource_changes": [{
      "address": "aws_security_group.bad_example",
      "type": "aws_security_group",
      "change": {
        "actions": ["create"],
        "after": {
          "ingress": [{
            "from_port": 22,
            "to_port": 22,
            "cidr_blocks": ["0.0.0.0/0"]
          }]
        }
      }
    }]
  }
}

# Prueba que valida que un SG bien configurado (SSH restringido) NO es
# rechazado por la politica (evita falsos positivos).
test_allow_ssh_restricted {
  count(deny) == 0 with input as {
    "resource_changes": [{
      "address": "aws_security_group.good_example",
      "type": "aws_security_group",
      "change": {
        "actions": ["create"],
        "after": {
          "ingress": [{
            "from_port": 22,
            "to_port": 22,
            "cidr_blocks": ["190.100.50.0/32"]
          }]
        }
      }
    }]
  }
}
