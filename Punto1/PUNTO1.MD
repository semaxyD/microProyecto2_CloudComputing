# Configuración de un Entorno Automatizado con Vagrant, Terraform y Ansible

# 1) Prerrequisitos en tu host

- **VirtualBox** y **Vagrant** instalados. (Vagrant es la herramienta oficial para gestionar entornos locales; si necesitas instalarlo en Ubuntu, puedes hacerlo vía `apt` o paquete .deb).
- Carpeta de proyecto, por ejemplo `parcial2/`.

Estructura que usaremos:

```
parcial2/
├─ Vagrantfile
├─ ansible/
│  ├─ inventory.ini
│  ├─ apache.yml
│  └─ templates/
│     └─ index.html.j2
└─ terraform/
   └─ main.tf
```

# 2) Vagrantfile (declara **control-node** y **web-node**)

Usamos la box **Ubuntu 22.04** (Bento mantiene `bento/ubuntu-22.04`, muy usada en guías de Vagrant). La red privada permite que las VMs se vean entre sí (p. ej. `192.168.56.0/24`). 

```ruby
# Vagrantfile
Vagrant.configure("2") do |config|
  config.vm.box_check_update = false

  # ---------- CONTROL NODE ----------
  config.vm.define "control-node" do |cn|
    cn.vm.box = "bento/ubuntu-22.04"
    cn.vm.hostname = "control-node"
    cn.vm.network "private_network", ip: "192.168.56.10" # red privada
    cn.vm.provider "virtualbox" do |vb|
      vb.memory = 2048
      vb.cpus   = 2
    end

    # Instalar Terraform y Ansible dentro del control-node
    cn.vm.provision "shell", inline: <<-SHELL
      set -eux
      sudo apt-get update -y
      sudo apt-get install -y software-properties-common gnupg curl

      # Terraform vía repo de HashiCorp
      curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
      echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg arch=$(dpkg --print-architecture)] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
      sudo apt-get update -y && sudo apt-get install -y terraform

      # Ansible (PPA oficial)
      sudo apt-add-repository -y ppa:ansible/ansible
      sudo apt-get update -y && sudo apt-get install -y ansible

      terraform -version
      ansible --version
    SHELL
  end

  # ---------- WEB NODE ----------
  config.vm.define "web-node" do |web|
    web.vm.box = "bento/ubuntu-22.04"
    web.vm.hostname = "web-node"
    web.vm.network "private_network", ip: "192.168.56.11"
    web.vm.provider "virtualbox" do |vb|
      vb.memory = 1024
      vb.cpus   = 1
    end
  end
end

```

# 3) Ansible (inventario + playbook + plantilla)

**Inventario**: apuntamos al `web-node` por IP privada y usamos el usuario `vagrant`.

Truco práctico: Ansible puede usar la **clave privada** que Vagrant genera para `web-node`, que suele quedar en:

`<proyecto>/.vagrant/machines/web-node/virtualbox/private_key`.

Como Vagrant comparte la carpeta del proyecto con el invitado en `/vagrant`, desde **control-node** esa clave estará en `/vagrant/.vagrant/machines/web-node/virtualbox/private_key`. (Vagrant comparte por defecto el directorio del proyecto a `/vagrant`). 

`ansible/inventory.ini`

```
[web]
web-node ansible_host=192.168.56.11 ansible_user=vagrant ansible_ssh_private_key_file=/home/vagrant/.ssh/ansible_id_rsa
```

**Playbook**: instala Apache, lo habilita/enciende, y deja una página de bienvenida. (Usamos módulos `apt`, `service` y `template` de Ansible). [docs.ansible.com+2docs.ansible.com+2](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/apt_module.html?utm_source=chatgpt.com)

`ansible/apache.yml`

```yaml
---
- name: Configurar Apache en web-node
  hosts: web
  become: true
  tasks:
    - name: Actualizar cache APT
      ansible.builtin.apt:
        update_cache: yes
        cache_valid_time: 3600

    - name: Instalar Apache
      ansible.builtin.apt:
        name: apache2
        state: present

    - name: Asegurar que Apache está habilitado y en ejecución
      ansible.builtin.service:
        name: apache2
        state: started
        enabled: yes

    - name: Página de bienvenida personalizada
      ansible.builtin.template:
        src: templates/index.html.j2
        dest: /var/www/html/index.html
        owner: www-data
        group: www-data
        mode: '0644'
```

`ansible/templates/index.html.j2`

```html
<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="UTF-8">
<title>Bienvenido</title>
<style>
    body {
    background: linear-gradient(135deg, #667eea, #764ba2);
    color: #fff;
    font-family: 'Segoe UI', sans-serif;
    text-align: center;
    padding-top: 20%;
    }
    h1 { font-size: 2.5rem; }
</style>
</head>
<body>
<h1>🚀 ¡Apache funciona en {{ inventory_hostname }}!</h1>
<p>Provisionado con Terraform + Ansible</p>
</body>
</html>
```

# 4) Terraform (dentro de **control-node**) para **disparar Ansible**

Aquí usamos un `null_resource` con **`local-exec`** para ejecutar `ansible-playbook`. Este patrón (post-apply con provisioners) es soportado por Terraform, aunque los provisioners se recomiendan como último recurso; en un **laboratorio local** como este es muy conveniente.

`terraform/main.tf`

```hcl
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
```

# 5) Ejecución paso a paso

1. **Levanta las VMs con Vagrant (desde tu host):**

```bash
cd parcial2
vagrant up     # creará control-node (10) y web-node (11)
```

1. **Entra al control-node:**

```bash
vagrant ssh control-node
```

1. **Corre Terraform (dentro de control-node):**

```bash
cd /vagrant/terraform
terraform init
terraform apply -auto-approve
```

Esto ejecutará el playbook de **Ansible** contra `web-node` usando el inventario que apunta a `192.168.56.11`.

1. **Prueba Apache (desde tu host):**
    
    Abre `http://192.168.56.11/` y deberías ver la página personalizada.