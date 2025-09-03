
CREATE DATABASE IF NOT EXISTS myflaskapp;
USE myflaskapp;

-- Tabla de usuarios
CREATE TABLE IF NOT EXISTS users (
    id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255),
    email VARCHAR(255),
    username VARCHAR(255),
    password VARCHAR(255)
);

CREATE TABLE IF NOT EXISTS products (
    id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    price INT NOT NULL,
    description VARCHAR(255) NOT NULL DEFAULT '',
    stock INT NOT NULL DEFAULT 0
);

-- Tabla de órdenes
CREATE TABLE IF NOT EXISTS orders (
    id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    userName VARCHAR(255),
    userEmail VARCHAR(255),
    saleTotal DECIMAL(10,2),
    products TEXT,
    date DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Datos de ejemplo para usuarios
INSERT INTO users (name, email, username, password) VALUES
    ('juan', 'juan@gmail.com', 'juan', '$2y$12$aEYylzcB/AnKx6gY7QyQieAc8UPL05.LOIJfiCY0ryvllwhsJfbay'),
    ('maria', 'maria@gmail.com', 'maria', '$2y$12$YCl/JoI5e4LysGKzKPMA4eWO6LVc9yoFIQ5njCFbRDqdFN7BJuddi'),
    ('oscar', 'oscar@gmail.com', 'oscar', '789'),
    ('ana', 'ana@gmail.com', 'ana', 'abc'),
    ('pedro', 'pedro@gmail.com', 'pedro', 'xyz'),
    ('lucia', 'lucia@gmail.com', 'lucia', 'pass1');

INSERT INTO products (name, price, description, stock) VALUES
    ('pc', 150, 'Computadora de escritorio', 10),
    ('phone', 100, 'Teléfono móvil', 20),
    ('tablet', 200, 'Tablet 10 pulgadas', 15),
    ('monitor', 80, 'Monitor LED', 25),
    ('mouse', 20, 'Mouse óptico', 50),
    ('keyboard', 30, 'Teclado mecánico', 40);
INSERT INTO products (name, price, description, stock) VALUES
    ('pc', 150, 'Computadora de escritorio', 10),
    ('phone', 100, 'Teléfono móvil', 20),
    ('tablet', 200, 'Tablet 10 pulgadas', 15),
    ('monitor', 80, 'Monitor LED', 25),
    ('mouse', 20, 'Mouse óptico', 50),
    ('keyboard', 30, 'Teclado mecánico', 40);
