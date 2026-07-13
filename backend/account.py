import os
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, HTTPException, Depends, Header
from supabase import create_client, Client
from dotenv import load_dotenv

from auth import get_current_user_id, get_current_admin_user_id

load_dotenv()

supabase_url = os.getenv("SUPABASE_URL")
supabase_service_key = os.getenv("SUPABASE_SERVICE_ROLE_KEY")

if not supabase_url or not supabase_service_key:
    raise ValueError("Variáveis de ambiente do Supabase não configuradas no Backend.")

supabase: Client = create_client(supabase_url, supabase_service_key)

# Carência entre o pedido de exclusão e a anonimização definitiva. Logar de
# novo dentro dessa janela cancela o pedido (feito no frontend, via
# /cancel-deletion). Padrão de mercado (Instagram/X) e alinhado ao espírito da LGPD.
GRACE_PERIOD_DAYS = 30

# Bane o login por ~100 anos (mantém a linha em auth.users viva, então o
# profile — que referencia auth.users ON DELETE CASCADE — sobrevive como âncora
# de FK; um delete de verdade apagaria o profile junto).
BAN_FOREVER = "876000h"

router = APIRouter(prefix="/api/account", tags=["Conta"])


def _raise_from_rpc_error(e: Exception):
    """Funções SQL levantam 'CODIGO: mensagem'. Mesma convenção de challenges.py."""
    message = getattr(e, "message", None) or str(e)
    if "NOT_FOUND" in message:
        status_code = 404
    elif any(code in message for code in (
        "BALANCE_NOT_EMPTY", "ACTIVE_MATCH", "ACTIVE_TOURNAMENT", "ALREADY_ANONYMIZED",
    )):
        status_code = 400
    else:
        status_code = 500

    detail = message.split(": ", 1)[1] if ": " in message else message
    raise HTTPException(status_code=status_code, detail=detail)


@router.post("/request-deletion")
def request_deletion(user_id: str = Depends(get_current_user_id)):
    """Marca a carência de exclusão. Bloqueia se houver saldo livre ou partida/
    torneio pago em andamento — validado dentro da função SQL."""
    try:
        result = supabase.rpc("fn_request_account_deletion", {"p_user_id": user_id}).execute()
        return {
            "status": "pending_deletion",
            "grace_period_days": GRACE_PERIOD_DAYS,
            "deletion_requested_at": (result.data or {}).get("deletion_requested_at"),
        }
    except HTTPException:
        raise
    except Exception as e:
        _raise_from_rpc_error(e)


@router.post("/cancel-deletion")
def cancel_deletion(user_id: str = Depends(get_current_user_id)):
    """Cancela um pedido de exclusão ainda dentro da carência (restaura a conta)."""
    try:
        supabase.rpc("fn_cancel_account_deletion", {"p_user_id": user_id}).execute()
        return {"status": "active"}
    except HTTPException:
        raise
    except Exception as e:
        _raise_from_rpc_error(e)


@router.post("/deactivate")
def deactivate(user_id: str = Depends(get_current_user_id)):
    """Desativa temporariamente (some da vitrine). Reversível a qualquer momento —
    login reativa. Bloqueia com partida/torneio em andamento (validado na SQL)."""
    try:
        supabase.rpc("fn_deactivate_account", {"p_user_id": user_id}).execute()
        return {"status": "deactivated"}
    except HTTPException:
        raise
    except Exception as e:
        _raise_from_rpc_error(e)


@router.post("/reactivate")
def reactivate(user_id: str = Depends(get_current_user_id)):
    """Reativa uma conta desativada (também chamado automaticamente ao logar)."""
    try:
        supabase.rpc("fn_reactivate_account", {"p_user_id": user_id}).execute()
        return {"status": "active"}
    except HTTPException:
        raise
    except Exception as e:
        _raise_from_rpc_error(e)


@router.post("/finalize-due-deletions")
def finalize_due_deletions(
    authorization: str = Header(default=None),
    x_cron_secret: str = Header(default=None),
):
    """Anonimiza em definitivo todas as contas cuja carência já venceu.

    Dois caminhos de autenticação:
      - Job agendado: header X-Cron-Secret == CRON_SECRET (env). É assim que o
        pg_cron chama (ver 25_schedule_deletion_finalize.sql) — segredo estático,
        sem depender de uma sessão de admin viva.
      - Manual: um admin logado (Bearer token) dispara na mão.
    Precisa banir o login no auth.users (Admin Auth API), então roda aqui no
    backend e não como função SQL pura.
    """
    cron_secret = os.getenv("CRON_SECRET")
    if cron_secret and x_cron_secret and x_cron_secret == cron_secret:
        pass  # autenticado como o job agendado
    else:
        get_current_admin_user_id(authorization)  # exige admin; levanta 401/403

    cutoff = (datetime.now(timezone.utc) - timedelta(days=GRACE_PERIOD_DAYS)).isoformat()

    due = (
        supabase.table("profiles")
        .select("id")
        .lt("deletion_requested_at", cutoff)
        .is_("anonymized_at", "null")
        .execute()
    )

    anonymized, failed = [], []
    for row in (due.data or []):
        uid = row["id"]
        try:
            # Bane o login ANTES de anonimizar — se o ban falhar, o profile fica
            # intacto e a conta é reprocessada na próxima rodada.
            supabase.auth.admin.update_user_by_id(uid, {"ban_duration": BAN_FOREVER})
            supabase.rpc("fn_anonymize_profile", {"p_user_id": uid}).execute()
            anonymized.append(uid)
        except Exception:
            # Ex.: saldo ainda não zerado (disputa creditou algo) — segura essa
            # conta e tenta de novo depois, sem derrubar o lote inteiro.
            failed.append(uid)

    return {"anonymized": len(anonymized), "skipped": len(failed)}
