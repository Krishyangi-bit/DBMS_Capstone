"""Capstone analytics surface: database-native intelligence exposed over REST.

Guests may read every analytical projection (the demo is public), while the
dispatch mutation requires an authenticated staff role and reuses the MySQL
stored procedure `sp_dispatch_relief_aid` whenever it is installed.
"""
from decimal import Decimal
from typing import Any, Dict, List, Optional

from fastapi import APIRouter, Depends, HTTPException, Query, Request, status
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.inventory import InventoryItem
from app.models.organization import Organization
from app.models.user import User
from app.core.deps import get_current_user, get_optional_user
from app.services import analytics as analytics_service
from app.services.db_programs import (
    dispatch_relief_aid_via_procedure,
    list_db_programs,
)
from app.services.stock import record_movement

router = APIRouter(prefix="/analytics", tags=["Analytics"])


def _resolve_org_id(db: Session, current_user: Optional[User], org_type: str) -> int:
    if current_user:
        return current_user.org_id
    org = db.query(Organization).filter(Organization.org_type == org_type).first()
    return org.id if org else 1


@router.get("/inventory-health")
def get_inventory_health(
    org_type: str = Query("ngo"),
    current_user: Optional[User] = Depends(get_optional_user),
    db: Session = Depends(get_db),
) -> List[Dict[str, Any]]:
    """`v_inventory_health_summary`: status, expiry risk, valuation and urgency index."""
    org_id = _resolve_org_id(db, current_user, org_type)
    return analytics_service.inventory_health(db, org_id)


@router.get("/stock-velocity")
def get_stock_velocity(
    item_id: Optional[int] = Query(None),
    limit: int = Query(100, ge=1, le=500),
    org_type: str = Query("ngo"),
    current_user: Optional[User] = Depends(get_optional_user),
    db: Session = Depends(get_db),
) -> List[Dict[str, Any]]:
    """Running cumulative balance per item using SUM() OVER (window function)."""
    org_id = _resolve_org_id(db, current_user, org_type)
    return analytics_service.stock_velocity(db, org_id, item_id=item_id, limit=limit)


@router.get("/category-velocity")
def get_category_velocity(
    days: int = Query(30, ge=1, le=365),
    top_n: int = Query(3, ge=1, le=20),
    org_type: str = Query("ngo"),
    current_user: Optional[User] = Depends(get_optional_user),
    db: Session = Depends(get_db),
) -> List[Dict[str, Any]]:
    """DENSE_RANK top-N fastest outflow items inside each category."""
    org_id = _resolve_org_id(db, current_user, org_type)
    return analytics_service.category_velocity(db, org_id, days=days, top_n=top_n)


@router.get("/cash-flow")
def get_cash_flow(
    limit: int = Query(200, ge=1, le=500),
    org_type: str = Query("ngo"),
    current_user: Optional[User] = Depends(get_optional_user),
    db: Session = Depends(get_db),
) -> Dict[str, Any]:
    """UNION ALL consolidated cash flow plus the reconciled inflow/outflow totals."""
    org_id = _resolve_org_id(db, current_user, org_type)
    return {
        "transactions": analytics_service.cash_flow(db, org_id, limit=limit),
        "totals": analytics_service.cash_flow_totals(db, org_id),
    }


@router.get("/dead-stock")
def get_dead_stock(
    days: int = Query(60, ge=1, le=365),
    org_type: str = Query("ngo"),
    current_user: Optional[User] = Depends(get_optional_user),
    db: Session = Depends(get_db),
) -> List[Dict[str, Any]]:
    """Anti-join + correlated subquery: idle stock above its category average."""
    org_id = _resolve_org_id(db, current_user, org_type)
    return analytics_service.dead_stock(db, org_id, days=days)


@router.get("/pnl")
def get_monthly_pnl(
    org_type: str = Query("ngo"),
    current_user: Optional[User] = Depends(get_optional_user),
    db: Session = Depends(get_db),
) -> List[Dict[str, Any]]:
    """`v_monthly_financial_pnl` with a cumulative-net-cash window column."""
    org_id = _resolve_org_id(db, current_user, org_type)
    return analytics_service.monthly_pnl(db, org_id)


@router.get("/warehouses")
def get_warehouse_distribution(
    org_type: str = Query("ngo"),
    current_user: Optional[User] = Depends(get_optional_user),
    db: Session = Depends(get_db),
) -> List[Dict[str, Any]]:
    """EER aggregation entity `warehouse_stock`, grouped per facility."""
    org_id = _resolve_org_id(db, current_user, org_type)
    return analytics_service.warehouse_distribution(db, org_id)


@router.get("/donation-specialization")
def get_donation_specialization(
    org_type: str = Query("ngo"),
    current_user: Optional[User] = Depends(get_optional_user),
    db: Session = Depends(get_db),
) -> List[Dict[str, Any]]:
    """EER proof: the two donation subclasses counted through their own relations."""
    org_id = _resolve_org_id(db, current_user, org_type)
    return analytics_service.donation_specialization_breakdown(db, org_id)


@router.get("/db-programs")
def get_db_programs() -> Dict[str, Any]:
    """Which triggers / procedures / functions / views are installed on the engine."""
    return list_db_programs()


class DispatchAidRequest(BaseModel):
    item_id: int = Field(..., gt=0)
    quantity: Decimal = Field(..., gt=0)
    destination: Optional[str] = Field(None, max_length=255)


@router.post("/dispatch-aid", status_code=status.HTTP_201_CREATED)
def dispatch_relief_aid(
    payload: DispatchAidRequest,
    request: Request,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> Dict[str, Any]:
    """Atomic relief dispatch.

    On MySQL with `stored_programs.sql` installed this executes
    `sp_dispatch_relief_aid` (row X-Lock + SAVEPOINT + COMMIT inside the engine).
    On SQLite, or MySQL without the procedure, it falls back to the ORM service
    which applies the same rules with `SELECT ... FOR UPDATE`.
    """
    if current_user.role.lower() not in ("admin", "manager", "volunteer"):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only admin, manager or volunteer roles may dispatch relief aid.",
        )

    org = db.get(Organization, current_user.org_id)
    if not org:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Organization not found.")
    if (org.org_type or "ngo").lower() != "ngo":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Relief dispatch is only available to NGO organizations.",
        )

    item = db.query(InventoryItem).filter(
        InventoryItem.id == payload.item_id,
        InventoryItem.org_id == current_user.org_id,
    ).first()
    if not item:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Inventory item not found.")

    destination = payload.destination or "Field Relief Dispatch"

    result = dispatch_relief_aid_via_procedure(
        org_id=current_user.org_id,
        item_id=payload.item_id,
        quantity=payload.quantity,
        actor_id=current_user.id,
        destination=destination,
    )

    if result is not None:
        dispatch_status = str(result.get("status", ""))
        if dispatch_status.upper().startswith("FAILED"):
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=dispatch_status,
            )
        if dispatch_status.upper().startswith("ERROR"):
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=dispatch_status,
            )
        db.expire_all()
        refreshed = db.get(InventoryItem, payload.item_id)
        return {
            "engine": "mysql_stored_procedure",
            "status": dispatch_status,
            "remaining_stock": float(result.get("remaining_stock", 0)),
            "item_name": item.name,
            "name": item.name,
            "quantity_dispatched": float(payload.quantity),
            "balance_after": float(refreshed.quantity_on_hand) if refreshed else None,
        }

    ip_addr = request.client.host if request.client else "127.0.0.1"
    movement = record_movement(
        db=db,
        org_id=current_user.org_id,
        item_id=payload.item_id,
        movement_type="RELIEF",
        quantity=payload.quantity,
        actor_user_id=current_user.id,
        note=destination,
        reference_type="aid_distribution",
        ip_address=ip_addr,
    )
    db.commit()
    db.refresh(item)

    return {
        "engine": "python_service_fallback",
        "status": "SUCCESS: Aid Dispatched",
        "remaining_stock": float(item.quantity_on_hand),
        "item_name": item.name,
        "name": item.name,
        "quantity_dispatched": float(payload.quantity),
        "movement_id": movement.id,
    }
