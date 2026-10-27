-- Factory Downtime Analysis - analysis queries (SQLite)
-- Run after 01_schema.sql and 02_seed_data.sql

-- Q1. Total downtime per machine (which machine stops the most?)
SELECT m.machine_id, m.machine_name, m.line,
       COUNT(d.id)              AS stop_count,
       COALESCE(SUM(d.minutes),0) AS total_min
FROM machine m
LEFT JOIN downtime_log d ON d.machine_id = m.machine_id
GROUP BY m.machine_id
ORDER BY total_min DESC;

-- Q2. Pareto of downtime causes with cumulative %
WITH by_cause AS (
    SELECT cause, SUM(minutes) AS total_min
    FROM downtime_log
    GROUP BY cause
)
SELECT cause, total_min,
       ROUND(100.0 * total_min / SUM(total_min) OVER (), 1) AS pct,
       ROUND(100.0 * SUM(total_min) OVER (ORDER BY total_min DESC)
                   / SUM(total_min) OVER (), 1)            AS cumulative_pct
FROM by_cause
ORDER BY total_min DESC;

-- Q3. Downtime by category and shift
SELECT category, shift, COUNT(*) AS stops, SUM(minutes) AS total_min
FROM downtime_log
GROUP BY category, shift
ORDER BY total_min DESC;

-- Q4. Monthly downtime trend per line
SELECT substr(d.start_time, 1, 7) AS month, m.line, SUM(d.minutes) AS total_min
FROM downtime_log d
JOIN machine m ON m.machine_id = d.machine_id
GROUP BY month, m.line
ORDER BY month, m.line;

-- Q5. MTBF / MTTR per machine (in minutes, unplanned stops only)
WITH fail AS (
    SELECT machine_id, COUNT(*) AS failures, SUM(minutes) AS down_min
    FROM downtime_log
    WHERE category <> 'Planned'
    GROUP BY machine_id
),
plan AS (
    SELECT machine_id, SUM(planned_min) AS planned_min
    FROM production_log
    GROUP BY machine_id
)
SELECT m.machine_id, m.machine_name, f.failures,
       ROUND(1.0 * (p.planned_min - f.down_min) / f.failures, 0) AS mtbf_min,
       ROUND(1.0 * f.down_min / f.failures, 1)                   AS mttr_min
FROM machine m
JOIN fail f ON f.machine_id = m.machine_id
JOIN plan p ON p.machine_id = m.machine_id
ORDER BY mtbf_min;

-- Q6. OEE per machine = Availability x Performance x Quality
WITH dt AS (
    SELECT machine_id, substr(start_time,1,10) AS prod_date, SUM(minutes) AS down_min
    FROM downtime_log GROUP BY machine_id, prod_date
),
daily AS (
    SELECT p.machine_id, p.planned_min,
           p.planned_min - COALESCE(dt.down_min,0) AS run_min,
           p.good_qty, p.ng_qty
    FROM production_log p
    LEFT JOIN dt ON dt.machine_id = p.machine_id AND dt.prod_date = p.prod_date
)
SELECT m.machine_id, m.machine_name,
       ROUND(1.0*SUM(run_min)/SUM(planned_min), 3)                          AS availability,
       ROUND(1.0*SUM(good_qty+ng_qty)/(SUM(run_min)/60.0*m.ideal_uph), 3)   AS performance,
       ROUND(1.0*SUM(good_qty)/SUM(good_qty+ng_qty), 3)                     AS quality,
       ROUND( (1.0*SUM(run_min)/SUM(planned_min))
            * (1.0*SUM(good_qty+ng_qty)/(SUM(run_min)/60.0*m.ideal_uph))
            * (1.0*SUM(good_qty)/SUM(good_qty+ng_qty)), 3)                 AS oee
FROM daily d
JOIN machine m ON m.machine_id = d.machine_id
GROUP BY m.machine_id
ORDER BY oee;

-- Q7. Top 3 causes for the worst machine (drill-down for FCA)
SELECT cause, COUNT(*) AS stops, SUM(minutes) AS total_min
FROM downtime_log
WHERE machine_id = (SELECT machine_id FROM downtime_log
                    GROUP BY machine_id ORDER BY SUM(minutes) DESC LIMIT 1)
GROUP BY cause
ORDER BY total_min DESC
LIMIT 3;
