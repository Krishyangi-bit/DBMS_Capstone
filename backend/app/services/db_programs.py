"""Bridge between the FastAPI application and the MySQL-native stored programs.

The application must run on SQLite for offline development/testing and on MySQL 8
for the capstone demonstration. This module is the single place that knows which
engine is active and what it can do:

* ``native_movement_triggers_active()`` — tells the stock service whether the
  database already maintains ``quantity_on_hand`` and the audit trail, so the
  Python code does not double-apply a movement.
* ``dispatch_relief_aid_via_procedure()`` — invokes ``sp_dispatch_relief_aid``
  (X-Lock + SAVEPOINT + TCL inside the engine) and returns ``None`` when the
  procedure is unavailable so the caller can fall back to the service layer.
* ``list_db_programs()`` — introspection used by the Analytics screen to prove the
  programs are installed.
"""
from __future__ import annotations

import logging
from typing import Any, Dict, List, Optional

from sqlalchemy import text

from app.database import engine

logger = logging.getLogger(__name__)

# Object inventory required by the capstone specification (Pillars 2, 3 and 4).
EXPECTED_PROGRAMS: List[tuple] = [
    ("trg_before_stock_movement_insert", "TRIGGER"),
    ("trg_after_stock_movement_insert", "TRIGGER"),
    ("sp_dispatch_relief_aid", "PROCEDURE"),
    ("sp_sweep_expired_batches", "PROCEDURE"),
    ("fn_compute_stock_urgency_score", "FUNCTION"),
    ("v_inventory_health_summary", "VIEW"),
    ("v_monthly_financial_pnl", "VIEW"),
    ("v_public_masked_catalog", "VIEW"),
]

_trigger_cache: Optional[bool] = None


def is_mysql() -> bool:
    return engine.dialect.name == "mysql"


def reset_program_cache() -> None:
    """Clear the cached trigger probe (used after installing/dropping programs)."""
    global _trigger_cache
    _trigger_cache = None


def native_movement_triggers_active() -> bool:
    """True when ``trg_after_stock_movement_insert`` exists on the live schema.

    The check is cached for the process lifetime: the SQL script instructs operators
    to restart the API after installing or dropping the triggers.
    """
    global _trigger_cache
    if _trigger_cache is not None:
        return _trigger_cache

    if not is_mysql():
        _trigger_cache = False
        return _trigger_cache

    try:
        with engine.connect() as conn:
            found = conn.execute(
                text(
                    "SELECT COUNT(*) FROM information_schema.TRIGGERS "
                    "WHERE TRIGGER_SCHEMA = DATABASE() "
                    "AND TRIGGER_NAME = 'trg_after_stock_movement_insert'"
                )
            ).scalar()
        _trigger_cache = bool(found)
    except Exception as exc:  # pragma: no cover - defensive against exotic setups
        logger.warning("Could not probe MySQL triggers, assuming none installed: %s", exc)
        _trigger_cache = False

    return _trigger_cache


def _installed_objects() -> set:
    """Return the set of (name, type) objects installed on the active schema."""
    installed = set()
    if is_mysql():
        with engine.connect() as conn:
            rows = conn.execute(
                text(
                    "SELECT TRIGGER_NAME AS name FROM information_schema.TRIGGERS "
                    "WHERE TRIGGER_SCHEMA = DATABASE()"
                )
            ).mappings().all()
            installed.update((r["name"], "TRIGGER") for r in rows)

            rows = conn.execute(
                text(
                    "SELECT ROUTINE_NAME AS name, ROUTINE_TYPE AS rtype "
                    "FROM information_schema.ROUTINES WHERE ROUTINE_SCHEMA = DATABASE()"
                )
            ).mappings().all()
            installed.update((r["name"], str(r["rtype"]).upper()) for r in rows)

            rows = conn.execute(
                text(
                    "SELECT TABLE_NAME AS name FROM information_schema.VIEWS "
                    "WHERE TABLE_SCHEMA = DATABASE()"
                )
            ).mappings().all()
            installed.update((r["name"], "VIEW") for r in rows)
    else:
        with engine.connect() as conn:
            rows = conn.execute(
                text(
                    "SELECT name, type FROM sqlite_master "
                    "WHERE type IN ('trigger', 'view')"
                )
            ).mappings().all()
            installed.update((r["name"], str(r["type"]).upper()) for r in rows)

    return installed


def list_db_programs() -> Dict[str, Any]:
    """Report which capstone stored programs are installed on the active database."""
    installed: set = set()
    error = None
    try:
        installed = _installed_objects()
    except Exception as exc:  # pragma: no cover - introspection failure is reported
        error = str(exc)

    programs = [
        {
            "name": name,
            "object_type": obj_type,
            "installed": (name, obj_type) in installed,
        }
        for name, obj_type in EXPECTED_PROGRAMS
    ]

    return {
        "engine": engine.dialect.name,
        "native_programs_supported": is_mysql(),
        "native_movement_triggers_active": native_movement_triggers_active(),
        "installed_count": sum(1 for p in programs if p["installed"]),
        "expected_count": len(programs),
        "programs": programs,
        "error": error,
        "install_script": "backend/sql/stored_programs.sql",
    }


def dispatch_relief_aid_via_procedure(
    org_id: int,
    item_id: int,
    quantity,
    actor_id: int,
    destination: str,
) -> Optional[Dict[str, Any]]:
    """Call ``sp_dispatch_relief_aid`` through the MySQL driver.

    Returns ``{"status": ..., "remaining_stock": ...}`` on success, or ``None`` when
    the procedure is not available (SQLite, or MySQL without the script installed),
    which signals the caller to use the Python service implementation instead.
    """
    if not is_mysql():
        return None

    raw = engine.raw_connection()
    try:
        cursor = raw.cursor()
        try:
            result = cursor.callproc(
                "sp_dispatch_relief_aid",
                [
                    int(org_id),
                    int(item_id),
                    float(quantity),
                    int(actor_id),
                    destination or "Field Dispatch",
                    "",
                    -1,
                ],
            )
            status = result[5] if len(result) > 5 else ""
            remaining = result[6] if len(result) > 6 else -1
        finally:
            cursor.close()
        raw.commit()

        if not status:
            return None
        return {"status": str(status), "remaining_stock": remaining}
    except Exception as exc:
        try:
            raw.rollback()
        except Exception:
            pass

        message = str(exc)
        # 1305 = PROCEDURE does not exist -> fall back to the service implementation
        if "1305" in message or "PROCEDURE" in message.upper() and "does not exist" in message:
            logger.warning("sp_dispatch_relief_aid unavailable, using service fallback: %s", message)
            return None
        raise
    finally:
        raw.close()
