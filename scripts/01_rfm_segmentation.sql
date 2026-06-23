-- 1. CTE para consolidar la tabla de hechos transaccionales
WITH base_transactions AS (
    SELECT 
        c.customer_unique_id,
        MAX(o.order_purchase_timestamp) AS last_purchase_date,
        COUNT(DISTINCT o.order_id) AS total_orders,
        SUM(oi.price) AS total_spent
    FROM customers c
    INNER JOIN orders o 
        ON c.customer_id = o.customer_id
    INNER JOIN order_items oi 
        ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
),

-- 2. CTE para calcular las métricas absolutas de RFM
rfm_metrics AS (
    SELECT 
        customer_unique_id,
        -- Recencia: Diferencia en días desde la compra más reciente en toda la base de datos
        EXTRACT(DAY FROM (SELECT MAX(last_purchase_date) FROM base_transactions) - last_purchase_date) AS recency_days,
        total_orders AS frequency,
        total_spent AS monetary
    FROM base_transactions
),

-- 3. CTE para asignar cuartiles usando Window Functions (El "Motor" analítico)
rfm_scoring AS (
    SELECT 
        customer_unique_id,
        recency_days,
        frequency,
        monetary,
        -- Entre menor recencia (más reciente), mejor puntaje (NTILE 4 es mejor)
        NTILE(4) OVER(ORDER BY recency_days DESC) AS r_score, 
        -- Entre mayor frecuencia, mejor puntaje
        NTILE(4) OVER(ORDER BY frequency ASC) AS f_score,     
        -- Entre mayor gasto, mejor puntaje
        NTILE(4) OVER(ORDER BY monetary ASC) AS m_score       
    FROM rfm_metrics
)

-- 4. Consulta final para exportar a Power BI
SELECT 
    customer_unique_id,
    recency_days,
    frequency,
    monetary,
    (r_score + f_score + m_score) AS rfm_total_score,
    CONCAT(r_score, f_score, m_score) AS rfm_cell
FROM rfm_scoring;