from flask import Blueprint, request, jsonify, session
from orders.models.order_model import Order
from db.db import db
import requests
import json

order_controller = Blueprint('order_controller', __name__)

# Listar todas las órdenes
@order_controller.route('/api/orders', methods=['GET'])
def get_all_orders():
    orders = Order.query.all()
    result = []
    for o in orders:
        result.append({
            'id': o.id,
            'userName': o.userName,
            'userEmail': o.userEmail,
            'saleTotal': o.saleTotal,
            'products': json.loads(o.products),
            'date': o.date.strftime('%Y-%m-%d %H:%M:%S') if o.date else None
        })
    return jsonify(result)

# Obtener una orden por ID
@order_controller.route('/api/orders/<int:order_id>', methods=['GET'])
def get_order(order_id):
    o = Order.query.get_or_404(order_id)
    return jsonify({
        'id': o.id,
        'userName': o.userName,
        'userEmail': o.userEmail,
        'saleTotal': o.saleTotal,
        'products': json.loads(o.products),
        'date': o.date.strftime('%Y-%m-%d %H:%M:%S') if o.date else None
    })

# Crear una nueva orden
@order_controller.route('/api/orders', methods=['POST'])
def create_order():
    print('POST /api/orders llamado')
    try:
        data = request.get_json(force=True)
        print('Datos recibidos:', data)
    except Exception as e:
        print('Error al obtener JSON:', e)
        return jsonify({'message': 'Error al obtener datos'}), 400

    user_name = session.get('username') or data.get('user', {}).get('name')
    user_email = session.get('email') or data.get('user', {}).get('email')
    if not user_name or not user_email:
        print('Error: Información de usuario inválida')
        return jsonify({'message': 'Información de usuario inválida'}), 400
    products = data.get('products')
    if not products or not isinstance(products, list):
        print('Error: Falta o es inválida la información de los productos')
        return jsonify({'message': 'Falta o es inválida la información de los productos'}), 400

    # Simulación: obtener productos y verificar stock
    total = 0
    unavailable = []
    updated_products = []
    for item in products:
        product_id = item.get('id')
        quantity = int(item.get('quantity', 0))
        print(f'Procesando producto {product_id} con cantidad {quantity}')
        # Llamada al microservicio de productos
        try:
            resp = requests.get(f'http://products:5003/api/products/{product_id}')
            print(f'Respuesta de productos: {resp.status_code}, {resp.text}')
            if resp.status_code != 200:
                unavailable.append(product_id)
                continue
            prod = resp.json()
            if prod['stock'] < quantity:
                print(f'Stock insuficiente para producto {product_id}')
                unavailable.append(product_id)
                continue
            total += prod['price'] * quantity
            updated_products.append({'id': product_id, 'new_stock': prod['stock'] - quantity})
        except Exception as e:
            print(f'Error al consultar producto {product_id}:', e)
            unavailable.append(product_id)

    if unavailable:
        print(f'Productos no disponibles o sin stock: {unavailable}')
        return jsonify({'message': f'Productos no disponibles o sin stock: {unavailable}'}), 400

    # Actualizar inventario en microProducts
    for up in updated_products:
        try:
            product_id = up["id"]
            print(f'Actualizando stock de producto {product_id} a {up["new_stock"]}')
            requests.put(f"http://products:5003/api/products/{product_id}", json={'stock': up['new_stock']})
        except Exception as e:
            print(f'Error al actualizar producto {product_id}:', e)

    # Crear la orden
    print('Creando orden...')
    new_order = Order(userName=user_name, userEmail=user_email, saleTotal=total, products=products)
    db.session.add(new_order)
    db.session.commit()
    print('Orden creada exitosamente')
    return jsonify({'message': 'Orden creada exitosamente'}), 201
