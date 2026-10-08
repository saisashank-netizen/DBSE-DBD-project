from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from sqlalchemy import text
from app.api.deps import get_db

router = APIRouter(prefix="/analytics", tags=["Advanced SQL Analytics (CO1)"])

@router.get("/carrier-rankings")
def get_carrier_rankings_window(db: Session = Depends(get_db)):
    """
    Executes an Advanced SQL query utilizing:
    - Multi-table JOINs (Carriers, Shipments, Invoices)
    - Aggregates (COUNT, SUM, AVG)
    - Window Functions: DENSE_RANK() OVER (ORDER BY total_revenue DESC)
    Fulfills CO1 syllabus requirement for Window Functions and Analytics.
    """
    sql_query = text("""
        WITH CarrierMetrics AS (
            SELECT
                c.carrier_id,
                c.carrier_name,
                COUNT(s.shipment_id) AS total_shipments,
                SUM(CASE WHEN s.status = 'delivered' THEN 1 ELSE 0 END) AS delivered_count,
                ROUND(AVG(s.weight_kg), 2) AS avg_weight_kg,
                COALESCE(SUM(i.amount), 0.00) AS total_revenue
            FROM Carriers c
            LEFT JOIN Shipments s ON c.carrier_id = s.carrier_id
            LEFT JOIN Invoices i ON s.shipment_id = i.shipment_id
            GROUP BY c.carrier_id, c.carrier_name
        )
        SELECT
            carrier_name,
            total_shipments,
            delivered_count,
            avg_weight_kg,
            total_revenue,
            DENSE_RANK() OVER (ORDER BY total_revenue DESC) AS revenue_rank,
            ROW_NUMBER() OVER (ORDER BY total_shipments DESC) AS volume_rank
        FROM CarrierMetrics
        ORDER BY revenue_rank ASC
        LIMIT 10;
    """)

    result = db.execute(sql_query)
    rows = []
    for r in result:
        rows.append({
            "carrier_name": r.carrier_name,
            "total_shipments": int(r.total_shipments),
            "delivered_count": int(r.delivered_count),
            "avg_weight_kg": float(r.avg_weight_kg or 0.0),
            "total_revenue": float(r.total_revenue),
            "revenue_rank": int(r.revenue_rank),
            "volume_rank": int(r.volume_rank)
        })
    return {"total_records": len(rows), "carrier_rankings": rows}


@router.get("/monthly-revenue-cte")
def get_monthly_revenue_cte(db: Session = Depends(get_db)):
    """
    Executes a Common Table Expression (CTE) query calculating monthly gross revenue,
    active shipments, and running cumulative spend.
    Fulfills CO1 syllabus requirement for CTEs and Recursive / Analytical SQL.
    """
    sql_query = text("""
        WITH MonthlyData AS (
            SELECT
                DATE_FORMAT(created_at, '%Y-%m') AS month_key,
                COUNT(shipment_id) AS shipment_count,
                SUM(estimated_cost) AS monthly_revenue
            FROM Shipments
            WHERE status != 'cancelled'
            GROUP BY DATE_FORMAT(created_at, '%Y-%m')
        )
        SELECT
            month_key,
            shipment_count,
            monthly_revenue,
            SUM(monthly_revenue) OVER (ORDER BY month_key ASC) AS cumulative_revenue
        FROM MonthlyData
        ORDER BY month_key DESC;
    """)

    result = db.execute(sql_query)
    rows = []
    for r in result:
        rows.append({
            "month": r.month_key,
            "shipment_count": int(r.shipment_count),
            "monthly_revenue": float(r.monthly_revenue or 0.0),
            "cumulative_revenue": float(r.cumulative_revenue or 0.0)
        })
    return {"monthly_financials": rows}
