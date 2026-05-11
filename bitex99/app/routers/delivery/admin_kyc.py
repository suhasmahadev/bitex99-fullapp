import uuid
from fastapi import APIRouter, HTTPException
from sqlalchemy import select, update
from app.dependencies import AdminUser, DB
from app.models.delivery_partner import DeliveryPartner
from app.models.kyc_document import KycDocument, DocType
from app.models.user import User
from app.schemas.kyc import AdminRejectRequest

router = APIRouter(prefix="/api/v1/admin/kyc", tags=["Admin KYC"])

def _value(value):
    return value.value if hasattr(value, "value") else value

@router.get("/pending")
async def get_pending_kyc(admin: AdminUser, db: DB):
    users = await db.scalars(select(User).where(User.partner_status == "KYC_SUBMITTED"))
    results = []
    
    for user in users:
        partner = await db.scalar(select(DeliveryPartner).where(DeliveryPartner.user_id == user.id))
        if not partner:
            continue
        docs = await db.scalars(select(KycDocument).where(KycDocument.partner_id == partner.id))
        doc_list = [
            {
                "doc_type": _value(d.doc_type),
                "file_url": d.file_url,
                "url": d.file_url,
                "status": _value(d.status),
                "uploaded_at": d.uploaded_at,
                "rejection_reason": d.rejection_reason,
            }
            for d in docs
        ]
        
        results.append({
            "partner_id": partner.id,
            "name": user.name,
            "fe_id": partner.fe_id,
            "phone": user.phone,
            "city": partner.city,
            "status": user.partner_status,
            "submitted_at": user.updated_at,
            "documents": doc_list
        })
        
    return results

@router.get("/approved")
async def get_approved_kyc(admin: AdminUser, db: DB, page: int = 1, limit: int = 10):
    page = max(page, 1)
    limit = min(max(limit, 1), 100)
    stmt = (
        select(User, DeliveryPartner)
        .join(DeliveryPartner, DeliveryPartner.user_id == User.id)
        .where(User.partner_status == "KYC_APPROVED")
        .order_by(User.updated_at.desc())
        .offset((page - 1) * limit)
        .limit(limit)
    )
    rows = (await db.execute(stmt)).all()
    return [
        {
            "partner_id": partner.id,
            "name": user.name,
            "fe_id": partner.fe_id,
            "phone": user.phone,
            "city": partner.city,
            "status": user.partner_status,
            "approved_at": user.updated_at,
        }
        for user, partner in rows
    ]

@router.post("/{partner_id}/approve")
async def approve_kyc(partner_id: uuid.UUID, admin: AdminUser, db: DB):
    partner = await db.scalar(select(DeliveryPartner).where(DeliveryPartner.id == partner_id))
    if not partner:
        raise HTTPException(status_code=404, detail="Partner not found")
        
    user = await db.scalar(select(User).where(User.id == partner.user_id))
    
    # Update documents
    await db.execute(
        update(KycDocument).where(KycDocument.partner_id == partner_id).values(status='APPROVED')
    )
    
    # Update user status
    user.partner_status = 'KYC_APPROVED'
    await db.commit()
    
    return {"message": f"KYC approved for {partner.fe_id}"}

@router.post("/{partner_id}/reject")
async def reject_kyc(partner_id: uuid.UUID, request: AdminRejectRequest, admin: AdminUser, db: DB):
    partner = await db.scalar(select(DeliveryPartner).where(DeliveryPartner.id == partner_id))
    if not partner:
        raise HTTPException(status_code=404, detail="Partner not found")
        
    user = await db.scalar(select(User).where(User.id == partner.user_id))
    
    try:
        doc_enum = DocType(request.doc_type)
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid doc_type")
        
    # Update document
    doc = await db.scalar(
        select(KycDocument).where(
            KycDocument.partner_id == partner_id,
            KycDocument.doc_type == doc_enum
        )
    )
    if not doc:
         raise HTTPException(status_code=404, detail="Document not found")
         
    doc.status = 'REJECTED'
    doc.rejection_reason = request.reason
    
    # Update user status
    user.partner_status = 'KYC_REJECTED'
    await db.commit()
    
    return {"message": "Document rejected"}
