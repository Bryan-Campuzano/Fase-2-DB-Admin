-- =====================================================================
-- Fase 2 - Lenguaje procedimental
-- Autor: Bryan Alexander Campuzano Giraldo
-- Curso: Administración de Bases de Datos (202016902) - UNAD
-- =====================================================================

-- ---------------------------------------------------------------------
-- 3a. Listar los pedidos con su cliente, tienda, total y fecha actual
-- ---------------------------------------------------------------------
SELECT 
    o.order_id,
    c.full_name AS cliente,
    s.store_name AS tienda,
    SUM(oi.quantity * oi.unit_price) AS total_pedido,
    SYSDATE AS fecha_actual
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
JOIN stores s ON o.store_id = s.store_id
JOIN order_items oi ON o.order_id = oi.order_id
GROUP BY o.order_id, c.full_name, s.store_name;

-- ---------------------------------------------------------------------
-- 3b. Primeros 12 pedidos cuyo total sea mayor que el promedio general
-- ---------------------------------------------------------------------
WITH TotalesPedidos AS (
    SELECT o.order_id, SUM(oi.quantity * oi.unit_price) AS total
    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    GROUP BY o.order_id
),
PromedioTotal AS (
    SELECT AVG(total) AS promedio FROM TotalesPedidos
)
SELECT 
    tp.order_id, 
    tp.total, 
    SYSDATE AS fecha_actual
FROM TotalesPedidos tp
CROSS JOIN PromedioTotal pt
WHERE tp.total > pt.promedio
FETCH FIRST 12 ROWS ONLY;

-- ---------------------------------------------------------------------
-- 3c. Listar tiendas y número de pedidos en cada una (LEFT JOIN)
-- ---------------------------------------------------------------------
SELECT 
    s.store_name,
    COUNT(o.order_id) AS numero_pedidos,
    SYSDATE AS fecha_actual
FROM stores s
LEFT JOIN orders o ON s.store_id = o.store_id
GROUP BY s.store_name;

-- ---------------------------------------------------------------------
-- 3d. Consulta optimizada (Se retiraron subconsultas escalares)
-- ---------------------------------------------------------------------
SELECT 
    c.full_name AS customer_name,
    s.store_name AS store_name,
    SUM(oi.quantity * oi.unit_price) AS order_total,
    s.store_name AS city
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
JOIN stores s ON o.store_id = s.store_id
JOIN order_items oi ON o.order_id = oi.order_id
GROUP BY c.full_name, s.store_name, o.order_id;

-- ---------------------------------------------------------------------
-- 4. Particionamiento de la tabla ORDERS por fecha
-- ---------------------------------------------------------------------
-- Creación de la tabla particionada
CREATE TABLE orders_part (
    order_id NUMBER,
    order_tms TIMESTAMP,
    customer_id NUMBER,
    store_id NUMBER,
    order_status VARCHAR2(20)
)
PARTITION BY RANGE (order_tms) (
    PARTITION p_2023 VALUES LESS THAN (TO_TIMESTAMP('2024-01-01', 'YYYY-MM-DD')),
    PARTITION p_2024 VALUES LESS THAN (TO_TIMESTAMP('2025-01-01', 'YYYY-MM-DD')),
    PARTITION p_2025 VALUES LESS THAN (TO_TIMESTAMP('2026-01-01', 'YYYY-MM-DD')),
    PARTITION p_max VALUES LESS THAN (MAXVALUE)
);

-- Poblar la tabla con datos originales
INSERT INTO orders_part (order_id, order_tms, customer_id, store_id, order_status)
SELECT order_id, order_tms, customer_id, store_id, order_status
FROM orders;

-- Verificación
SELECT * FROM orders_part PARTITION (p_2024);

-- ---------------------------------------------------------------------
-- 5. Procedimiento almacenado: Actualizar precios de productos por tienda
-- ---------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE actualizar_precios_tienda (
    p_store_id IN NUMBER,
    p_porcentaje_aumento IN NUMBER
) AS
BEGIN
    UPDATE products p
    SET p.unit_price = p.unit_price * (1 + (p_porcentaje_aumento / 100))
    WHERE p.product_id IN (
        SELECT i.product_id 
        FROM inventory i 
        WHERE i.store_id = p_store_id
    );
    COMMIT;
END;
/

-- Ejecución
BEGIN
    actualizar_precios_tienda(1, 10);
END;
/

-- ---------------------------------------------------------------------
-- 6. Trigger: Registrar cambios de inventario
-- ---------------------------------------------------------------------
-- Creación de tabla de historial
CREATE TABLE inventory_history (
    hist_id NUMBER GENERATED ALWAYS AS IDENTITY,
    product_id NUMBER,
    store_id NUMBER,
    old_inventory NUMBER,
    new_inventory NUMBER,
    change_date TIMESTAMP
);

-- Creación del Trigger
CREATE OR REPLACE TRIGGER trg_audit_inventory
AFTER UPDATE OF product_inventory ON inventory
FOR EACH ROW
BEGIN
    INSERT INTO inventory_history (product_id, store_id, old_inventory, new_inventory, change_date)
    VALUES (:OLD.product_id, :OLD.store_id, :OLD.product_inventory, :NEW.product_inventory, SYSDATE);
END;
/

-- ---------------------------------------------------------------------
-- 7. Vista Materializada: Calcular valor total de inventario por tienda
-- ---------------------------------------------------------------------
CREATE MATERIALIZED VIEW mv_valor_inventario_tienda
REFRESH COMPLETE
START WITH SYSDATE NEXT SYSDATE + 7
AS
SELECT 
    i.store_id,
    SUM(i.product_inventory * p.unit_price) AS valor_total_inventario
FROM inventory i
JOIN products p ON i.product_id = p.product_id
GROUP BY i.store_id;

-- ---------------------------------------------------------------------
-- 8. Función almacenada: Calcular el valor total de una orden
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION calcular_total_orden (f_order_id NUMBER) 
RETURN NUMBER IS
    v_total NUMBER := 0;
BEGIN
    SELECT SUM(quantity * unit_price) INTO v_total
    FROM order_items
    WHERE order_id = f_order_id;
    
    RETURN NVL(v_total, 0);
END;
/

-- Verificación
SELECT order_id, calcular_total_orden(order_id) AS total_calculado FROM orders;

-- ---------------------------------------------------------------------
-- 9. Cursor explícito: Listar productos y calcular inventario de tienda
-- ---------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE calcular_inv_cursor (p_store_id NUMBER) IS
    CURSOR c_productos IS
        SELECT p.product_name, i.product_inventory, p.unit_price
        FROM inventory i
        JOIN products p ON i.product_id = p.product_id
        WHERE i.store_id = p_store_id;
        
    v_valor_total NUMBER := 0;
    v_valor_parcial NUMBER;
BEGIN
    FOR r_prod IN c_productos LOOP
        v_valor_parcial := r_prod.product_inventory * r_prod.unit_price;
        DBMS_OUTPUT.PUT_LINE('Prod: ' || r_prod.product_name || ' | Valor: ' || v_valor_parcial);
        v_valor_total := v_valor_total + v_valor_parcial;
    END LOOP;
    DBMS_OUTPUT.PUT_LINE('Valor TOTAL Inventario Tienda ' || p_store_id || ': ' || v_valor_total);
END;
/

-- Ejecución
BEGIN
    calcular_inv_cursor(1);
END;
/

-- ---------------------------------------------------------------------
-- 10. Cursor explícito: Actualizar estado de órdenes pendientes
-- ---------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE actualizar_ordenes_pendientes IS
    CURSOR c_ordenes IS
        SELECT order_id
        FROM orders
        WHERE order_status = 'PENDIENTE' 
        AND order_tms < SYSDATE - 5;
BEGIN
    FOR r_orden IN c_ordenes LOOP
        UPDATE orders 
        SET order_status = 'CANCELADA' 
        WHERE order_id = r_orden.order_id;
    END LOOP;
    COMMIT;
END;
/

-- Ejecución
BEGIN
    actualizar_ordenes_pendientes();
END;
/

-- ---------------------------------------------------------------------
-- 11. Procedimiento IN/OUT: Número de órdenes y valor total de ventas
-- ---------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE stats_ventas_tienda (
    p_store_id IN NUMBER,
    p_num_ordenes OUT NUMBER,
    p_valor_ventas OUT NUMBER
) IS
BEGIN
    SELECT COUNT(DISTINCT o.order_id), SUM(oi.quantity * oi.unit_price)
    INTO p_num_ordenes, p_valor_ventas
    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    WHERE o.store_id = p_store_id;
    
    p_valor_ventas := NVL(p_valor_ventas, 0);
END;
/

-- Ejecución
DECLARE
    v_ords NUMBER;
    v_ventas NUMBER;
BEGIN
    stats_ventas_tienda(1, v_ords, v_ventas);
    DBMS_OUTPUT.PUT_LINE('Ordenes: ' || v_ords || ' | Ventas Totales: ' || v_ventas);
END;
/

-- ---------------------------------------------------------------------
-- 12. Procedimiento: Inserción en CUSTOMERS con manejo de errores
-- ---------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE insertar_cliente (
    p_email VARCHAR2,
    p_full_name VARCHAR2
) IS
    v_existe NUMBER;
    e_email_duplicado EXCEPTION;
BEGIN
    SELECT COUNT(*) INTO v_existe FROM customers WHERE email_address = p_email;
    IF v_existe > 0 THEN
        RAISE e_email_duplicado;
    END IF;

    INSERT INTO customers (full_name, email_address) 
    VALUES (p_full_name, p_email);
    COMMIT;
    
EXCEPTION
    WHEN e_email_duplicado THEN
        DBMS_OUTPUT.PUT_LINE('Error: El email ' || p_email || ' ya existe.');
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error inesperado: ' || SQLERRM);
        ROLLBACK;
END;
/

-- Ejecución (Prueba exitosa y prueba de error)
BEGIN
    insertar_cliente('nuevo.cliente@correo.com', 'Juan Perez');
    -- insertar_cliente('nuevo.cliente@correo.com', 'Juan Perez'); -- Si se descomenta, arrojará el error controlado
END;
/

-- ---------------------------------------------------------------------
-- 13. Trigger: Auditar cambios de precio en PRODUCTS
-- ---------------------------------------------------------------------
-- Creación de tabla de auditoría
CREATE TABLE price_audit (
    audit_id NUMBER GENERATED ALWAYS AS IDENTITY,
    product_id NUMBER,
    old_price NUMBER,
    new_price NUMBER,
    change_date TIMESTAMP
);

-- Creación del Trigger
CREATE OR REPLACE TRIGGER trg_audit_price
AFTER UPDATE OF unit_price ON products
FOR EACH ROW
BEGIN
    INSERT INTO price_audit (product_id, old_price, new_price, change_date)
    VALUES (:OLD.product_id, :OLD.unit_price, :NEW.unit_price, SYSDATE);
END;
/