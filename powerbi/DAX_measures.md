# Power BI build guide

## 1. Load data
Home → **Get Data → Text/CSV** → load `machine.csv`, `downtime_log.csv`, `production_log.csv`.
In Power Query, check types: `start_time` = Date/Time, `prod_date` = Date, `minutes`, `planned_min`, `good_qty`, `ng_qty` = Whole Number.

Add a column to `downtime_log` (Add Column → Custom Column):
```
prod_date = DateTime.Date([start_time])
```

## 2. Relationships (Model view)
- `machine[machine_id]` 1 → * `downtime_log[machine_id]`
- `machine[machine_id]` 1 → * `production_log[machine_id]`

## 3. Measures (New measure)
```DAX
Total Downtime (min) = SUM ( downtime_log[minutes] )

Stop Count = COUNTROWS ( downtime_log )

Unplanned Stops =
CALCULATE ( [Stop Count], downtime_log[category] <> "Planned" )

Unplanned Downtime (min) =
CALCULATE ( [Total Downtime (min)], downtime_log[category] <> "Planned" )

Planned Time (min) = SUM ( production_log[planned_min] )

Run Time (min) = [Planned Time (min)] - [Total Downtime (min)]

MTTR (min) = DIVIDE ( [Unplanned Downtime (min)], [Unplanned Stops] )

MTBF (min) =
DIVIDE ( [Planned Time (min)] - [Unplanned Downtime (min)], [Unplanned Stops] )

Good Qty = SUM ( production_log[good_qty] )
Total Qty = SUM ( production_log[good_qty] ) + SUM ( production_log[ng_qty] )

Availability = DIVIDE ( [Run Time (min)], [Planned Time (min)] )

Performance =
DIVIDE (
    [Total Qty],
    SUMX ( machine, CALCULATE ( [Run Time (min)] ) / 60 * machine[ideal_uph] )
)

Quality = DIVIDE ( [Good Qty], [Total Qty] )

OEE = [Availability] * [Performance] * [Quality]

Pareto Cumulative % =
VAR CurrentMin = [Total Downtime (min)]
VAR Running =
    CALCULATE (
        [Total Downtime (min)],
        FILTER (
            ALL ( downtime_log[cause] ),
            [Total Downtime (min)] >= CurrentMin
        )
    )
RETURN DIVIDE ( Running, CALCULATE ( [Total Downtime (min)], ALL ( downtime_log[cause] ) ) )
```
Format Availability, Performance, Quality, OEE and Pareto % as **Percentage**.

## 4. Suggested page layout
| Area | Visual | Fields |
|---|---|---|
| Top row | 4 Cards | Total Downtime, Stop Count, MTTR, OEE |
| Left | Clustered bar | machine_name × Total Downtime |
| Right | Line and clustered column (Pareto) | cause × Total Downtime (column) + Pareto Cumulative % (line) |
| Bottom left | Line chart | prod_date × Total Downtime, legend = line |
| Bottom right | Matrix | machine_name × Availability, Performance, Quality, OEE |
| Side | Slicers | line, shift, category, prod_date |

Save screenshot as `images/dashboard.png` and the file as `powerbi/factory_downtime.pbix`.
