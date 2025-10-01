import os
from flask import Flask, render_template
from orders.controllers.order_controller import order_controller
from db.db import db
from flask_cors import CORS

app = Flask(__name__)
CORS(app)

app.config.from_object('config.Config')
db.init_app(app)

# Registrando el blueprint del controlador de usuarios
app.register_blueprint(order_controller)

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