import os

class Config:
    DEBUG = os.getenv('FLASK_ENV', 'production') == 'development'
    
    # URLs de los microservicios usando variables de entorno
    USERS_SERVICE_HOST = os.getenv('USERS_SERVICE_HOST', 'localhost')
    USERS_SERVICE_PORT = os.getenv('USERS_SERVICE_PORT', '5002')
    PRODUCTS_SERVICE_HOST = os.getenv('PRODUCTS_SERVICE_HOST', 'localhost') 
    PRODUCTS_SERVICE_PORT = os.getenv('PRODUCTS_SERVICE_PORT', '5003')
    ORDERS_SERVICE_HOST = os.getenv('ORDERS_SERVICE_HOST', 'localhost')
    ORDERS_SERVICE_PORT = os.getenv('ORDERS_SERVICE_PORT', '5004')
    
    # URLs completas para los servicios
    USERS_SERVICE_URL = f"http://{USERS_SERVICE_HOST}:{USERS_SERVICE_PORT}"
    PRODUCTS_SERVICE_URL = f"http://{PRODUCTS_SERVICE_HOST}:{PRODUCTS_SERVICE_PORT}"
    ORDERS_SERVICE_URL = f"http://{ORDERS_SERVICE_HOST}:{ORDERS_SERVICE_PORT}"
