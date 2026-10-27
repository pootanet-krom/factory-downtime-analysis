-- Factory Downtime Analysis - schema (SQLite)
DROP TABLE IF EXISTS downtime_log;
DROP TABLE IF EXISTS production_log;
DROP TABLE IF EXISTS machine;

CREATE TABLE machine (
    machine_id     TEXT PRIMARY KEY,
    machine_name   TEXT NOT NULL,
    line           TEXT NOT NULL,
    ideal_uph      INTEGER NOT NULL      -- ideal units per hour
);

CREATE TABLE downtime_log (
    id             INTEGER PRIMARY KEY,
    machine_id     TEXT NOT NULL REFERENCES machine(machine_id),
    start_time     TEXT NOT NULL,        -- 'YYYY-MM-DD HH:MM'
    minutes        INTEGER NOT NULL,
    cause          TEXT NOT NULL,
    category       TEXT NOT NULL,
    shift          TEXT NOT NULL         -- Day / Night
);

CREATE TABLE production_log (
    prod_date      TEXT NOT NULL,        -- 'YYYY-MM-DD'
    machine_id     TEXT NOT NULL REFERENCES machine(machine_id),
    planned_min    INTEGER NOT NULL,
    good_qty       INTEGER NOT NULL,
    ng_qty         INTEGER NOT NULL,
    PRIMARY KEY (prod_date, machine_id)
);
