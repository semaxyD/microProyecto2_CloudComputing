from db.db import db

class Products(db.Model):
    __tablename__ = 'products'
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(255), nullable=False)
    price = db.Column(db.Integer, nullable=False)
    description = db.Column(db.String(255), nullable=False, default='')
    stock = db.Column(db.Integer, nullable=False, default=0)

    def __init__(self, name, price, description='', stock=0):
        self.name = name
        self.price = price
        self.description = description
        self.stock = stock
