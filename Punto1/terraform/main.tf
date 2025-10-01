terraform {
  required_version = ">= 1.3.0"
}

# Recurso "dummy" para ejecutar Ansible desde control-node
resource "null_resource" "configure_web" {
  # Cambia esto si quieres re-ejecutar por cambio de archivo, etc.
  triggers = {
    always = timestamp()
  }

  provisioner "local-exec" {
    working_dir = "/vagrant/ansible"
    # Desactivamos check del fingerprint para simplificar el lab
    command = "cp /vagrant/.vagrant/machines/web-node/virtualbox/private_key ~/.ssh/ansible_id_rsa && chmod 600 ~/.ssh/ansible_id_rsa && ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i inventory.ini apache.yml"
  }
}
