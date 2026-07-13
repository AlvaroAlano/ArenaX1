import os
from typing import Optional

from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel, Field
from supabase import create_client, Client
from dotenv import load_dotenv

from auth import get_current_user_id

load_dotenv()

supabase_url = os.getenv("SUPABASE_URL")
supabase_service_key = os.getenv("SUPABASE_SERVICE_ROLE_KEY")

if not supabase_url or not supabase_service_key:
    raise ValueError("Variáveis de ambiente do Supabase não configuradas no Backend.")

supabase: Client = create_client(supabase_url, supabase_service_key)

router = APIRouter(prefix="/api/support", tags=["Suporte"])

# Espelha o CHECK de support_tickets.category (migração 28). O que não bater
# vira 'other' — nunca deixa a categoria do corpo furar o constraint da SQL.
ALLOWED_CATEGORIES = {"badge_contest", "match", "wallet", "account", "other"}


class OpenTicketRequest(BaseModel):
    category: str = "other"
    message: str = Field(min_length=5, max_length=4000)
    challenge_id: Optional[str] = None


class TicketReplyRequest(BaseModel):
    message: str = Field(min_length=1, max_length=4000)


def _raise_from_rpc_error(e: Exception):
    """Funções SQL levantam 'CODIGO: mensagem'. Mesma convenção de account.py."""
    message = getattr(e, "message", None) or str(e)
    if "MESSAGE_TOO_SHORT" in message:
        status_code = 400
    elif "NOT_FOUND" in message:
        status_code = 404
    elif "NOT_ALLOWED" in message:
        status_code = 403
    else:
        status_code = 500
    detail = message.split(": ", 1)[1] if ": " in message else message
    raise HTTPException(status_code=status_code, detail=detail)


def _is_admin(user_id: str) -> bool:
    """Confere profiles.is_admin do usuário logado (mesmo check das RPCs)."""
    try:
        res = supabase.table("profiles").select("is_admin").eq("id", user_id).single().execute()
        return bool((res.data or {}).get("is_admin"))
    except Exception:
        return False


@router.post("/tickets")
def open_ticket(request: OpenTicketRequest, user_id: str = Depends(get_current_user_id)):
    """Abre um ticket de suporte ("e-mail interno").

    O user_id vem SEMPRE do JWT verificado, nunca do corpo. A função SQL grava o
    ticket amarrado a esse usuário e ALERTA os admins (requisito obrigatório da
    opção C — sem alerta, um inbox que ninguém olha é promessa vazia).
    """
    category = request.category if request.category in ALLOWED_CATEGORIES else "other"
    try:
        result = supabase.rpc("fn_open_support_ticket", {
            "p_user_id": user_id,
            "p_category": category,
            "p_message": request.message,
            "p_challenge_id": request.challenge_id,
        }).execute()
        return {"status": "open", "ticket": result.data}
    except HTTPException:
        raise
    except Exception as e:
        _raise_from_rpc_error(e)


@router.get("/tickets")
def list_my_tickets(user_id: str = Depends(get_current_user_id)):
    """Lista os tickets do usuário logado (mais recentes por atividade)."""
    try:
        res = supabase.table("support_tickets").select("*").eq(
            "user_id", user_id
        ).order("updated_at", desc=True).execute()
        return res.data or []
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Erro ao carregar seus tickets: {str(e)}")


@router.get("/tickets/{ticket_id}")
def get_ticket_thread(ticket_id: str, user_id: str = Depends(get_current_user_id)):
    """Ticket + thread de mensagens. Autoriza o DONO ou um admin (a mesma tela
    de conversa serve os dois lados)."""
    try:
        ticket_res = supabase.table("support_tickets").select(
            "*, user_profile:user_id(username, fair_play_rating)"
        ).eq("id", ticket_id).single().execute()
        ticket = ticket_res.data
    except Exception:
        raise HTTPException(status_code=404, detail="Ticket não encontrado.")

    if ticket["user_id"] != user_id and not _is_admin(user_id):
        raise HTTPException(status_code=403, detail="Você não tem acesso a este ticket.")

    try:
        msgs_res = supabase.table("support_ticket_messages").select("*").eq(
            "ticket_id", ticket_id
        ).order("created_at", desc=False).execute()
        return {"ticket": ticket, "messages": msgs_res.data or []}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Erro ao carregar a conversa: {str(e)}")


@router.post("/tickets/{ticket_id}/reply")
def reply_ticket(ticket_id: str, request: TicketReplyRequest, user_id: str = Depends(get_current_user_id)):
    """Responde um ticket. A função SQL decide se a fala é do suporte (admin que
    não é o dono) ou do usuário, e notifica o outro lado."""
    try:
        result = supabase.rpc("fn_reply_support_ticket", {
            "p_ticket_id": ticket_id,
            "p_sender_id": user_id,
            "p_body": request.message,
        }).execute()
        return result.data
    except HTTPException:
        raise
    except Exception as e:
        _raise_from_rpc_error(e)
