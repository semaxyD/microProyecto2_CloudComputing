from flask import Blueprint, request, jsonify
from products.models.product_model import Products
from db.db import db

product_controller = Blueprint('product_controller', __name__)

# Obtener todos los productos
@product_controller.route('/api/products', methods=['GET'])
def get_products():
    products = Products.query.all()
    result = [
        {
            'id': p.id,
            'name': p.name,
            'description': p.description,
            'price': p.price,
            'stock': p.stock
        } for p in products
    ]
    return jsonify(result)

# Obtener un producto por ID
@product_controller.route('/api/products/<int:product_id>', methods=['GET'])
def get_product(product_id):
    product = Products.query.get_or_404(product_id)
    return jsonify({
        'id': product.id,
        'name': product.name,
        'description': product.description,
        'price': product.price,
        'stock': product.stock
    })

# Crear producto
@product_controller.route('/api/products', methods=['POST'])
def create_product():
    data = request.json
    new_product = Products(
        name=data['name'],
        description=data['description'],
        price=data['price'],
        stock=data['stock']
    )
    db.session.add(new_product)
    db.session.commit()
    return jsonify({'message': 'Product created successfully'}), 201

# Actualizar producto
@product_controller.route('/api/products/<int:product_id>', methods=['PUT'])
def update_product(product_id):
    product = Products.query.get_or_404(product_id)
    data = request.json
    product.name = data.get('name', product.name)
    product.description = data.get('description', product.description if hasattr(product, 'description') else '')
    product.price = data.get('price', product.price)
    # Usar 'quantity' si viene del frontend, sino mantener el valor actual
    product.stock = data.get('quantity', product.stock)
    db.session.commit()
    return jsonify({'message': 'Product updated successfully'})

# Eliminar producto
@product_controller.route('/api/product/<int:product_id>', methods=['DELETE'])
def delete_product(product_id):
    product = Products.query.get_or_404(product_id)
    db.session.delete(product)
    db.session.commit()
    return jsonify({'message': 'Product deleted successfully'})
