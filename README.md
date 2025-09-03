# Microproyecto #1 - Arquitectura de Microservicios

Este proyecto implementa una arquitectura de microservicios utilizando **Consul** para el descubrimiento de servicios, **Docker** para la contenerización y un **frontend web** para la interacción con los usuarios.

## 🏗️ Arquitectura del Sistema

El proyecto consta de los siguientes microservicios:

- **microUsers**: Gestión de usuarios
- **microProducts**: Gestión de productos
- **microOrders**: Gestión de órdenes (nueva implementación)
- **frontend**: Interfaz web para la administración
- **Consul**: Descubrimiento y registro de servicios

## 📋 Requisitos Previos

- **Vagrant** - Para gestionar la máquina virtual
- **Docker** y **Docker Compose** - Para la contenerización
- **VirtualBox** o similar - Hipervisor para Vagrant
- Conexión a internet para descargar dependencias

## 🚀 Instrucciones de Ejecución

### 1. Levantar la Máquina Virtual

```bash
vagrant up
```

### 2. Acceder a la Máquina Virtual

```bash
vagrant ssh
```

### 3. Iniciar los Contenedores

```bash
cd /vagrant
docker compose up -d
```

### 4. Verificar el Estado de los Servicios

```bash
docker compose ps
```

## 🌐 Acceso a las Aplicaciones

- **Frontend Web**: [http://192.168.80.3:5001](http://192.168.80.3:5001)
- **Consul UI**: [http://192.168.80.3:8500](http://192.168.80.3:8500)

## 📁 Estructura del Proyecto

```
microProyecto1_CloudComputing/
├── frontend/                    # Interfaz web
│   ├── web/
│   │   ├── static/             # Archivos estáticos (JS, CSS)
│   │   ├── templates/          # Plantillas HTML
│   │   └── views.py            # Vistas del frontend
│   ├── Dockerfile
│   └── requirements.txt
├── microUsers/                 # Microservicio de usuarios
│   ├── users/
│   ├── Dockerfile
│   └── requirements.txt
├── microProducts/              # Microservicio de productos
│   ├── products/
│   ├── Dockerfile
│   └── requirements.txt
├── microOrders/                # Microservicio de órdenes
│   ├── orders/
│   ├── Dockerfile
│   └── requirements.txt
├── docker-compose.yml          # Configuración de Docker Compose
├── Vagrantfile                 # Configuración de Vagrant
└── init.sql                    # Script de inicialización de BD
```

## 🔧 Implementación del Microservicio Orders

### Configuración de la Aplicación y Consul

**Archivo principal**: `microOrders/orders/views.py`

### Frontend - Gestión de Órdenes

- **Vista de órdenes**: `frontend/web/templates/orders.html`
- **Edición de órdenes**: `frontend/web/templates/editOrder.html`
- **JavaScript**: `frontend/web/static/scriptOrders.js`

### Dockerfiles

- **Frontend**: `frontend/Dockerfile`
- **Orders**: `microOrders/Dockerfile`

## 🧪 Pruebas del Sistema

### Verificar Funcionamiento de Consul

1. **Detener el microservicio Orders**:
   ```bash
   docker compose stop orders
   ```

2. **Verificar en Consul UI**:
   - Accede a [http://192.168.80.3:8500](http://192.168.80.3:8500)
   - Observa que el servicio `orders` aparece como **parado** (stopped)

3. **Reiniciar el servicio**:
   ```bash
   docker compose start orders
   ```

4. **Verificar recuperación**:
   - El servicio debería aparecer como **activo** (passing) en Consul

### Verificar Logs de los Servicios

```bash
# Ver logs de todos los servicios
docker compose logs

# Ver logs de un servicio específico
docker compose logs orders
docker compose logs frontend
```

## 🔍 Solución de Problemas

### Servicio no disponible
- Verificar que todos los contenedores estén ejecutándose: `docker compose ps`
- Revisar logs específicos: `docker compose logs <servicio>`

### Problemas de conectividad
- Verificar configuración de red en Vagrant
- Comprobar que los puertos estén libres en el host

### Errores de Consul
- Reiniciar Consul: `docker compose restart consul`
- Verificar configuración en los archivos `config.py` de cada microservicio

## 📊 Estado de los Servicios

Los servicios deberían estar disponibles en:
- **Users API**: Puerto interno del contenedor
- **Products API**: Puerto interno del contenedor
- **Orders API**: Puerto interno del contenedor
- **Frontend**: [http://192.168.80.3:5001](http://192.168.80.3:5001)
- **Consul**: [http://192.168.80.3:8500](http://192.168.80.3:8500)

## 🛠️ Comandos Útiles

```bash
# Detener todos los servicios
docker compose down

# Reconstruir y reiniciar servicios
docker compose up --build -d

# Ver logs en tiempo real
docker compose logs -f

# Acceder a un contenedor
docker compose exec <servicio> bash
```

## 1. Configuración de Dockerfile para la creación de contenedores

El Dockerfile define cómo se construye la imagen de cada microservicio. Por ejemplo, el Dockerfile de `orders`:

```Dockerfile
FROM python:3.9-slim
# Se usa una imagen ligera de Python para reducir el tamaño y mejorar la seguridad.
WORKDIR /app
# Define el directorio de trabajo dentro del contenedor.
RUN apt-get update && apt-get install -y \
		gcc \
		default-libmysqlclient-dev \
		pkg-config \
		&& rm -rf /var/lib/apt/lists/*
# Instala dependencias necesarias para conectar con MySQL y compilar paquetes Python.
COPY requirements.txt .
# Copia el archivo de dependencias de Python.
RUN pip install --no-cache-dir -r requirements.txt
# Instala las dependencias del proyecto.
COPY . .
# Copia el resto del código fuente al contenedor.
EXPOSE 5004
# Expone el puerto en el que correrá el microservicio.
CMD ["python", "run.py"]
# Comando que inicia la aplicación Flask.
```

**¿Por qué?**
Esto permite que cada microservicio se ejecute de forma aislada, con sus propias dependencias y configuración, facilitando el despliegue y la escalabilidad.

## 2. Configuración del descubrimiento con flask_consulate en microservicios

Para que los microservicios se descubran entre sí y sean monitoreados, se usa Consul junto con la extensión flask_consulate. Ejemplo en `views.py` de `microOrders`:

```python
from flask import Flask, render_template
from orders.controllers.order_controller import order_controller
from db.db import db
from flask_cors import CORS
from flask_consulate import Consul

app = Flask(__name__)
CORS(app)
# Permite peticiones desde otros dominios (CORS), útil para el frontend.

@app.route('/healthcheck')
def health_check():
		"""
		Esta función indica el estado actual al Consul.
		Formato: https://www.consul.io/docs/agent/checks.html
		"""
		return 'OK', 200
# Endpoint que Consul usa para verificar si el microservicio está vivo.

app.config['CONSUL_HOST'] = 'consul-server'
app.config['CONSUL_PORT'] = 8500
# Configura la conexión al servidor Consul.

consul = Consul(app=app)
# Inicializa la extensión flask_consulate.
consul.apply_remote_config(namespace='mynamespace/')
# Aplica configuración remota si existe.
consul.register_service(
		name='orders-microservice',
		interval='10s',
		tags=['microservice', 'orders'],
		port=5004,
		httpcheck='http://orders:5004/healthcheck'
)
# Registra el microservicio en Consul para descubrimiento y monitoreo.

app.config.from_object('config.Config')
db.init_app(app)
# Inicializa la base de datos.
app.register_blueprint(order_controller)
# Registra las rutas del controlador de órdenes.

@app.after_request
def apply_cors_headers(response):
		response.headers['Access-Control-Allow-Origin'] = 'http://localhost:5001'
		response.headers['Access-Control-Allow-Credentials'] = 'true'
		response.headers['Access-Control-Allow-Headers'] = 'Content-Type,Authorization'
		response.headers['Access-Control-Allow-Methods'] = 'GET,POST,PUT,DELETE,OPTIONS'
		return response
# Asegura que las respuestas incluyan los headers necesarios para CORS.

if __name__ == '__main__':
		app.run()
# Inicia la aplicación Flask.
```

**¿Por qué?**
Consul permite que los microservicios se registren y sean descubiertos automáticamente, facilitando la comunicación y el monitoreo en arquitecturas distribuidas.

## 3. Configuración del docker-compose.yml

El archivo `docker-compose.yml` define y orquesta todos los servicios del sistema. Ejemplo:

```yaml
services:
	mysql:
		image: mysql:8.0
		container_name: mysql
		restart: always
		environment:
			MYSQL_ROOT_PASSWORD: root
			MYSQL_DATABASE: myflaskapp
		ports:
			- "3306:3306"
		volumes:
			- ./init.sql:/docker-entrypoint-initdb.d/init.sql
		networks:
			- app-net
# Define la base de datos MySQL y la inicializa con el script init.sql.

	consul-server:
		image: consul:1.15
		container_name: consul-server
		command: "agent -server -bootstrap -ui -client=0.0.0.0"
		ports:
			- "8500:8500"
		networks:
			- app-net
# Inicia el servidor Consul con interfaz web y modo bootstrap.

	consul-client:
		image: consul:1.15
		container_name: consul-client
		command: "agent -retry-join=consul-server -client=0.0.0.0 -config-dir=/consul/config"
		depends_on:
			- consul-server
		networks:
			- app-net
# Cliente Consul que se une al servidor para registrar servicios.

	users:
		build: ./microUsers
		container_name: users
		ports:
			- "5002:5002"
		volumes:
			- ./microUsers:/app
		depends_on:
			- mysql
			- consul-client
			- consul-server
		environment:
			CONSUL_HOST: consul-server
			CONSUL_PORT: "8500"
			CONSUL_SCHEME: http
		restart: unless-stopped
		networks:
			- app-net
# Microservicio de usuarios, depende de la base de datos y Consul.

	products:
		build: ./microProducts
		container_name: products
		ports:
			- "5003:5003"
		volumes:
			- ./microProducts:/app
		depends_on:
			- mysql
			- consul-client
			- consul-server
		environment:
			CONSUL_HOST: consul-server
			CONSUL_PORT: "8500"
			CONSUL_SCHEME: http
		restart: unless-stopped
		networks:
			- app-net
# Microservicio de productos, depende de la base de datos y Consul.

	orders:
		build: ./microOrders
		container_name: orders
		ports:
			- "5004:5004"
		volumes:
			- ./microOrders:/app
		depends_on:
			- mysql
			- consul-client
			- consul-server
		environment:
			CONSUL_HOST: consul-server
			CONSUL_PORT: "8500"
			CONSUL_SCHEME: http
		restart: unless-stopped
		networks:
			- app-net
# Microservicio de órdenes, depende de la base de datos y Consul.

	frontend:
		build: ./frontend
		container_name: frontend
		ports:
			- "5001:5001"
		volumes:
			- ./frontend:/app
		depends_on:
			- mysql
			- users
			- products
			- orders
			- consul-client
			- consul-server
		environment:
			CONSUL_HOST: consul-server
			CONSUL_PORT: "8500"
			CONSUL_SCHEME: http
		restart: unless-stopped
		networks:
			- app-net
# Frontend web, depende de todos los microservicios y Consul.

networks:
	app-net:
		driver: bridge
# Red interna para que los servicios se comuniquen entre sí.
```

**¿Por qué?**
Docker Compose permite levantar y coordinar todos los servicios con un solo comando, facilitando el desarrollo, pruebas y despliegue.

---


