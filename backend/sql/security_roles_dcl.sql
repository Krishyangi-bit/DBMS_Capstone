-- =====================================================================================
--  ResourceOne Capstone — Pillar 6: Database-Controlled Security (DCL / RBAC)
--  Target: MySQL 8.0. Run as an administrative account:
--      mysql -u root -p < backend/sql/security_roles_dcl.sql
--
--  Design principle: the web tier is NOT a security boundary. Even if the FastAPI
--  process is compromised or a developer writes a raw query, the engine refuses
--  privileges the role does not hold. Three least-privilege roles mirror the
--  application's RBAC matrix (admin / clerk / auditor).
--
--  NOTE: change the demo passwords before using this anywhere real, and keep the
--  connection string for the API on the `app_service` account only.
-- =====================================================================================

SET NAMES utf8mb4;
USE resourceone;

-- -------------------------------------------------------------------------------------
--  1. Native MySQL roles
-- -------------------------------------------------------------------------------------
CREATE ROLE IF NOT EXISTS 'role_app_auditor';
CREATE ROLE IF NOT EXISTS 'role_app_clerk';
CREATE ROLE IF NOT EXISTS 'role_app_admin';

-- Start from a clean slate so the script is re-runnable
REVOKE ALL PRIVILEGES, GRANT OPTION FROM 'role_app_auditor';
REVOKE ALL PRIVILEGES, GRANT OPTION FROM 'role_app_clerk';
REVOKE ALL PRIVILEGES, GRANT OPTION FROM 'role_app_admin';

-- -------------------------------------------------------------------------------------
--  2. AUDITOR — read-only reporting. No raw transaction tables, no password hashes.
-- -------------------------------------------------------------------------------------
GRANT SELECT ON resourceone.v_inventory_health_summary TO 'role_app_auditor';
GRANT SELECT ON resourceone.v_monthly_financial_pnl    TO 'role_app_auditor';
GRANT SELECT ON resourceone.v_public_masked_catalog    TO 'role_app_auditor';
GRANT SELECT ON resourceone.activity_logs              TO 'role_app_auditor';
GRANT SELECT ON resourceone.stock_movements            TO 'role_app_auditor';

-- Column-level privilege: the auditor may see identity, never the credential hash
GRANT SELECT (id, org_id, full_name, email, role, is_active, created_at)
   ON resourceone.users TO 'role_app_auditor';

-- -------------------------------------------------------------------------------------
--  3. CLERK — shop-floor operations: record movements and purchases, never delete.
-- -------------------------------------------------------------------------------------
GRANT SELECT, INSERT           ON resourceone.stock_movements TO 'role_app_clerk';
GRANT SELECT, INSERT           ON resourceone.purchases       TO 'role_app_clerk';
GRANT SELECT, INSERT           ON resourceone.donations       TO 'role_app_clerk';
GRANT SELECT, INSERT           ON resourceone.cash_donations  TO 'role_app_clerk';
GRANT SELECT, INSERT           ON resourceone.in_kind_donations TO 'role_app_clerk';
GRANT SELECT, UPDATE           ON resourceone.inventory_items TO 'role_app_clerk';
GRANT SELECT                   ON resourceone.warehouses      TO 'role_app_clerk';
GRANT SELECT, INSERT, UPDATE   ON resourceone.warehouse_stock TO 'role_app_clerk';
GRANT SELECT                   ON resourceone.v_inventory_health_summary TO 'role_app_clerk';

-- Explicit denial of destructive DML on the whole schema
REVOKE DELETE, DROP ON resourceone.* FROM 'role_app_clerk';

-- The clerk executes the dispatch procedure but cannot touch the raw ledger directly
-- beyond INSERT/SELECT granted above. EXECUTE is scoped to the single routine.
GRANT EXECUTE ON PROCEDURE resourceone.sp_dispatch_relief_aid TO 'role_app_clerk';

-- -------------------------------------------------------------------------------------
--  4. ADMIN — full operational authority over the tenant schema
-- -------------------------------------------------------------------------------------
GRANT SELECT, INSERT, UPDATE, DELETE ON resourceone.* TO 'role_app_admin';
GRANT EXECUTE ON PROCEDURE resourceone.sp_dispatch_relief_aid   TO 'role_app_admin';
GRANT EXECUTE ON PROCEDURE resourceone.sp_sweep_expired_batches TO 'role_app_admin';

-- -------------------------------------------------------------------------------------
--  5. Dedicated service accounts (one per role; no shared superuser)
-- -------------------------------------------------------------------------------------
CREATE USER IF NOT EXISTS 'auditor_user'@'%' IDENTIFIED BY 'Auditor@Secure2026';
CREATE USER IF NOT EXISTS 'clerk_user'@'%'   IDENTIFIED BY 'Clerk@Secure2026';
CREATE USER IF NOT EXISTS 'admin_user'@'%'   IDENTIFIED BY 'Admin@Secure2026';

-- The API's own connection: reports + inventory, deliberately NOT full DDL rights
CREATE USER IF NOT EXISTS 'app_service'@'%'  IDENTIFIED BY 'AppService@Secure2026';

GRANT 'role_app_auditor' TO 'auditor_user'@'%';
GRANT 'role_app_clerk'   TO 'clerk_user'@'%';
GRANT 'role_app_admin'   TO 'admin_user'@'%';
GRANT 'role_app_clerk'   TO 'app_service'@'%';

SET DEFAULT ROLE 'role_app_auditor' TO 'auditor_user'@'%';
SET DEFAULT ROLE 'role_app_clerk'   TO 'clerk_user'@'%';
SET DEFAULT ROLE 'role_app_admin'   TO 'admin_user'@'%';
SET DEFAULT ROLE 'role_app_clerk'   TO 'app_service'@'%';

FLUSH PRIVILEGES;

-- -------------------------------------------------------------------------------------
--  6. Verification queries for the viva
-- -------------------------------------------------------------------------------------
-- Which roles does each account have?
SELECT grantee, role_name, is_default
  FROM mysql.role_edges
 WHERE TO_HOST = '%'
 ORDER BY grantee;

-- What can the auditor actually touch?
SHOW GRANTS FOR 'auditor_user'@'%';

-- What can the clerk actually touch? (DELETE must be absent)
SHOW GRANTS FOR 'clerk_user'@'%';
