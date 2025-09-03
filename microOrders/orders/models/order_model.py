from db.db import db
import json

class Order(db.Model):
    
    __tablename__ = 'orders'
    
    id = db.Column(db.Integer, primary_key=True)
    userName = db.Column(db.String(255), nullable=False)
    userEmail = db.Column(db.String(255), nullable=False)
    saleTotal = db.Column(db.Float, nullable=False)
    products = db.Column(db.Text, nullable=False)  # JSON string
    date = db.Column(db.DateTime, server_default=db.func.current_timestamp())

    def __init__(self, userName, userEmail, saleTotal, products):
        self.userName = userName
        self.userEmail = userEmail
        self.saleTotal = saleTotal
        self.products = json.dumps(products)
