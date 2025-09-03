CREATE DATABASE IF NOT EXISTS myflaskapp;
USE myflaskapp;

CREATE TABLE IF NOT EXISTS users (
    id int NOT NULL AUTO_INCREMENT PRIMARY KEY,
    name varchar(255),
    email varchar(255),
    username varchar(255),
    password varchar(255)
);

CREATE TABLE IF NOT EXISTS products (
    id int NOT NULL AUTO_INCREMENT PRIMARY KEY,
    name varchar(255),
    price int,
    quantity int,
    description varchar(255) NOT NULL DEFAULT '',
    stock int NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS orders (
    id int NOT NULL AUTO_INCREMENT PRIMARY KEY,
    userName varchar(255),
    userEmail varchar(255),
    saleTotal decimal(10,2),
    products text,
    date datetime default current_timestamp
);

-- Seed solo si la tabla está vacía
INSERT INTO users (name, email, username, password)
SELECT name, email, username, password
FROM (
    SELECT 'juan'  AS name, 'juan@gmail.com'  AS email, 'juan'  AS username, '$2y$12$aEYylzcB/AnKx6gY7QyQieAc8UPL05.LOIJfiCY0ryvllwhsJfbay'  AS password UNION ALL
    SELECT 'maria' AS name, 'maria@gmail.com' AS email, 'maria' AS username, '$2y$12$YCl/JoI5e4LysGKzKPMA4eWO6LVc9yoFIQ5njCFbRDqdFN7BJuddi'  AS password UNION ALL
    SELECT 'oscar' AS name, 'oscar@gmail.com' AS email, 'oscar' AS username, '789'  AS password UNION ALL
    SELECT 'ana'   AS name, 'ana@gmail.com'   AS email, 'ana'   AS username, 'abc'  AS password UNION ALL
    SELECT 'pedro' AS name, 'pedro@gmail.com' AS email, 'pedro' AS username, 'xyz'  AS password UNION ALL
    SELECT 'lucia' AS name, 'lucia@gmail.com' AS email, 'lucia' AS username, 'pass1' AS password
) AS seed
WHERE NOT EXISTS (SELECT 1 FROM users LIMIT 1);

INSERT INTO products (name, price, quantity)
SELECT name, price, quantity
FROM (
    SELECT 'pc'       AS name, 150 AS price, 10 AS quantity UNION ALL
    SELECT 'phone'    AS name, 100 AS price, 20 AS quantity UNION ALL
    SELECT 'tablet'   AS name, 200 AS price, 15 AS quantity UNION ALL
    SELECT 'monitor'  AS name,  80 AS price, 25 AS quantity UNION ALL
    SELECT 'mouse'    AS name,  20 AS price, 50 AS quantity UNION ALL
    SELECT 'keyboard' AS name,  30 AS price, 40 AS quantity
) AS seed
WHERE NOT EXISTS (SELECT 1 FROM products LIMIT 1);
