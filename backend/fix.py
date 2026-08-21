import sys
sys.path.append('d:/picgallery/backend')
from app.db.session import engine
from sqlalchemy import text
with engine.begin() as conn:
    conn.execute(text("UPDATE users SET current_plan='trial', plan_status='active', plan_expiry='2026-08-26 06:08:42+00:00', trial_used=true WHERE email='mkhimaniya741@rku.ac.in' AND role='photographer'"))
print('Done!')
