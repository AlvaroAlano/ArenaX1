import os
from datetime import datetime, timezone
from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel
from typing import List, Optional
from supabase import create_client, Client
from dotenv import load_dotenv

from auth import get_current_user_id

load_dotenv()

supabase_url = os.getenv("SUPABASE_URL")
supabase_service_key = os.getenv("SUPABASE_SERVICE_ROLE_KEY")

if not supabase_url or not supabase_service_key:
    raise ValueError("Variáveis de ambiente do Supabase não configuradas no Backend.")

supabase: Client = create_client(supabase_url, supabase_service_key)

router = APIRouter(prefix="/api/notifications", tags=["Notificações"])


class NotificationOut(BaseModel):
    id: str
    type: str
    title: str
    body: str
    tournament_id: Optional[str] = None
    match_id: Optional[str] = None
    challenge_id: Optional[str] = None
    ticket_id: Optional[str] = None
    read_at: Optional[str] = None
    created_at: str


class MarkReadRequest(BaseModel):
    ids: Optional[List[str]] = None  # None = marca todas como lidas


class NotificationFeedOut(BaseModel):
    unread_count: int
    notifications: List[NotificationOut]


@router.get("", response_model=NotificationFeedOut)
def get_notifications(user_id: str = Depends(get_current_user_id)):
    try:
        notifications_res = supabase.table("notifications").select("*").eq(
            "user_id", user_id
        ).order("created_at", desc=True).limit(30).execute()
        notifications = notifications_res.data or []

        unread_res = supabase.table("notifications").select("id").eq(
            "user_id", user_id
        ).is_("read_at", "null").execute()
        unread_count = len(unread_res.data or [])

        return {"unread_count": unread_count, "notifications": notifications}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Erro ao carregar notificações: {str(e)}")


@router.post("/mark-read")
def mark_notifications_read(request: MarkReadRequest, user_id: str = Depends(get_current_user_id)):
    try:
        now_iso = datetime.now(timezone.utc).isoformat()
        query = supabase.table("notifications").update({"read_at": now_iso}).eq("user_id", user_id).is_("read_at", "null")
        if request.ids:
            query = query.in_("id", request.ids)
        query.execute()
        return {"status": "success"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Erro ao marcar notificações como lidas: {str(e)}")
