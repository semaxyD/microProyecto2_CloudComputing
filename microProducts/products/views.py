from flask import Flask
from products.controllers.product_controller import product_controller
from db.db import db
from flask_cors import CORS
from flask_consulate import Consul

app = Flask(__name__)
CORS(app,resources={r"/api/*": {"origins": "*"}}, supports_credentials=True)

@app.route('/healthcheck')
def health_check():
	"""
	This function is used to say current status to the Consul.
	Format: https://www.consul.io/docs/agent/checks.html

	:return: Empty response with status 200, 429 or 500
	"""
	# TODO: implement any other checking logic.
	return 'OK', 200

app.config['CONSUL_HOST'] = 'consul-server'
app.config['CONSUL_PORT'] = 8500
# Consul
# This extension should be the first one if enabled:
consul = Consul(app=app)
# Fetch the configuration:
consul.apply_remote_config(namespace='mynamespace/')
# Register Consul service:
consul.register_service(
	name='product-microservice',
	interval='10s',
	tags=['microservice','products' ],
	port=5003,
	httpcheck='http://products:5003/healthcheck'
)

# Cargar configuración de la base de datos
app.config.from_object('config.Config')

# Inicializar SQLAlchemy
db.init_app(app)

# Registrar el blueprint del controlador
app.register_blueprint(product_controller)

if __name__ == '__main__':
	app.run()
