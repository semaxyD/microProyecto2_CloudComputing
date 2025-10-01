import os
from flask import Flask
from products.controllers.product_controller import product_controller
from db.db import db
from flask_cors import CORS

app = Flask(__name__)
CORS(app)

# Cargar configuración de la base de datos
app.config.from_object('config.Config')

# Inicializar SQLAlchemy
db.init_app(app)

# Registrar el blueprint del controlador
app.register_blueprint(product_controller)

@app.after_request
def apply_cors_headers(response):
    # Usar variable de entorno para CORS en lugar de IP hardcodeada
    frontend_host = os.getenv('FRONTEND_HOST', 'http://localhost:5001')
    response.headers['Access-Control-Allow-Origin'] = frontend_host
    response.headers['Access-Control-Allow-Credentials'] = 'true'
    response.headers['Access-Control-Allow-Headers'] = 'Content-Type,Authorization'
    response.headers['Access-Control-Allow-Methods'] = 'GET,POST,PUT,DELETE,OPTIONS'
    return response

if __name__ == '__main__':
	app.run()	
