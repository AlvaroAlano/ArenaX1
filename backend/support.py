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


def _raise_from_rpc_error(e: Exception):
    """Funções SQL levantam 'CODIGO: mensagem'. Mesma convenção de account.py."""
    message = getattr(e, "message", None) or str(e)
    if "MESSAGE_TOO_SHORT" in message:
        status_code = 400
    elif "NOT_FOUND" in message:
        status_code = 404
    else:
        status_code = 500
    detail = message.split(": ", 1)[1] if ": " in message else message
    raise HTTPException(status_code=status_code, detail=detail)


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
