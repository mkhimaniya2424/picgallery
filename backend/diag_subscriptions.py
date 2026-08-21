"""
Diagnostic: Check subscription plan state for all photographer accounts
and verify the plan_expiry timezone handling.
"""
import sys
sys.path.append('d:/picgallery/backend')

from app.db.session import engine
from app.schemas.user import UserRead
from sqlalchemy import text

with engine.connect() as conn:
    rows = conn.execute(text("""
        SELECT 
            email, role, current_plan, plan_status, plan_expiry,
            trial_used, plan_started_at, subscription_status
        FROM (
            SELECT u.*,
                CASE 
                    WHEN u.plan_status = 'active' AND u.current_plan = 'trial' THEN 'trial'
                    WHEN u.plan_status = 'active' THEN 'active'
                    WHEN u.plan_status = 'expired' THEN 'expired'
                    ELSE 'none'
                END AS subscription_status
            FROM users u
        ) AS enriched
        WHERE role = 'photographer'
        ORDER BY email
    """)).fetchall()

print(f"{'EMAIL':<35} {'PLAN':<10} {'STATUS':<10} {'SUB_STATUS':<12} {'EXPIRY':<30} {'TRIAL_USED'}")
print("-" * 120)
for r in rows:
    expiry = str(r.plan_expiry) if r.plan_expiry else 'None'
    print(f"{r.email:<35} {str(r.current_plan):<10} {r.plan_status:<10} {r.subscription_status:<12} {expiry:<30} {r.trial_used}")

print("\n--- plan_expiry timezone check ---")
tz_rows = conn.execute(text("""
    SELECT column_name, data_type 
    FROM information_schema.columns 
    WHERE table_name = 'users' 
    AND column_name IN ('plan_expiry', 'plan_started_at')
""")).fetchall()
for r in tz_rows:
    print(f"  Column: {r.column_name}, DB type: {r.data_type}")
