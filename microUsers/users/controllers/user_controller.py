from flask import Blueprint, request, jsonify, session, g, current_app
from users.models.user_model import Users
from db.db import db
from datetime import timedelta


user_controller = Blueprint('user_controller', __name__)

@user_controller.route('/api/users', methods=['GET'])
def get_users():
    print("listado de usuarios")

    #print(g.__dict__)

    users = Users.query.all()
    result = [{'id':user.id, 'name': user.name, 'email': user.email, 'username': user.username} for user in users]
    return jsonify(result)

# Get single user by id
@user_controller.route('/api/users/<int:user_id>', methods=['GET'])
def get_user(user_id):
    print("obteniendo usuario")
    user = Users.query.get_or_404(user_id)
    return jsonify({'id': user.id, 'name': user.name, 'email': user.email, 'username': user.username})

@user_controller.route('/api/users', methods=['POST'])
def create_user():
    print("creando usuario")
    import bcrypt
    data = request.json
    password = data['password']
    hashed = bcrypt.hashpw(password.encode('utf-8'), bcrypt.gensalt())
    new_user = Users(name=data['name'], email=data['email'], username=data['username'], password=hashed.decode('utf-8'))
    db.session.add(new_user)
    db.session.commit()
    return jsonify({'message': 'User created successfully'}), 201

# Update an existing user
@user_controller.route('/api/users/<int:user_id>', methods=['PUT'])
def update_user(user_id):
    print("actualizando usuario")
    user = Users.query.get_or_404(user_id)
    data = request.json
    user.name = data['name']
    user.email = data['email']
    user.username = data['username']
    user.password = data['password']
    db.session.commit()
    return jsonify({'message': 'User updated successfully'})

# Delete an existing user
@user_controller.route('/api/users/<int:user_id>', methods=['DELETE'])
def delete_user(user_id):
    user = Users.query.get_or_404(user_id)
    db.session.delete(user)
    db.session.commit()
    return jsonify({'message': 'User deleted successfully'})

@user_controller.route('/api/login', methods=['POST'])
def login():
    data = request.json

    username = data.get('username')
    password = data.get('password')

    if not username or not password:
        return jsonify({'message': 'Missing username or password'}),400

    user = Users.query.filter_by(username=username).first()

    if not user:
        return jsonify({'message': 'Invalid username or password'}), 401

    #if not check_password_hash(user.password, password):
    import bcrypt
    print('Password ingresada:', password)
    print('Hash en BD:', user.password)
    resultado = bcrypt.checkpw(password.encode('utf-8'), user.password.encode('utf-8'))
    print('Resultado bcrypt:', resultado)
    if not resultado:
        return jsonify({'message': 'Invalid username or password'}), 401

    import jwt
    import datetime
    # Store user information in session
    session['user_id'] = user.id
    session['username'] = user.username
    session['email'] = user.email

    # Generar JWT
    payload = {
        'user_id': user.id,
        'username': user.username,
        'email': user.email,
        'exp': datetime.datetime.utcnow() + datetime.timedelta(hours=2)
    }
    token = jwt.encode(payload, current_app.config['SECRET_KEY'], algorithm='HS256')
    print("En session: ",session)
    return jsonify({'message': 'Login successful', 'token': token, 'user_id': user.id, 'username': user.username, 'email': user.email})
