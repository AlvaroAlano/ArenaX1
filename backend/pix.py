import os
import uuid
from typing import Optional
from fastapi import APIRouter, HTTPException, Depends, Header
from pydantic import BaseModel
from supabase import create_client, Client
from dotenv import load_dotenv

from auth import get_current_user_id

load_dotenv()

# Inicialização do Supabase Client com chave administrativa (service_role)
supabase_url = os.getenv("SUPABASE_URL")
supabase_service_key = os.getenv("SUPABASE_SERVICE_ROLE_KEY")
pix_webhook_secret = os.getenv("PIX_WEBHOOK_SECRET")

if not supabase_url or not supabase_service_key:
    raise ValueError("Variáveis de ambiente do Supabase não configuradas no Backend.")

supabase: Client = create_client(supabase_url, supabase_service_key)

router = APIRouter(prefix="/api/pix", tags=["Pix & Financeiro"])

# Schemas Pydantic
class DepositRequest(BaseModel):
    amount: float

class WebhookPayload(BaseModel):
    external_id: str
    amount: float
    status: str  # 'completed' ou 'failed'

class WithdrawRequest(BaseModel):
    amount: float
    pix_key: str


# Schemas de resposta: fixam o contrato consumido pelo frontend.
class DepositOut(BaseModel):
    transaction_id: str
    external_id: str
    amount: float
    copia_e_cola: str
    qr_code_url: str

class WebhookOut(BaseModel):
    status: str
    message: str
    new_balance: Optional[float] = None

class WithdrawOut(BaseModel):
    status: str
    message: str
    amount: float
    new_balance: float


def _raise_from_rpc_error(e: Exception):
    message = getattr(e, "message", None) or str(e)
    if "INSUFFICIENT_BALANCE" in message:
        status_code = 400
    elif "NOT_FOUND" in message:
        status_code = 404
    elif "AMOUNT_MISMATCH" in message or "INVALID_AMOUNT" in message:
        status_code = 400
    else:
        status_code = 500

    detail = message.split(": ", 1)[1] if ": " in message else message
    raise HTTPException(status_code=status_code, detail=detail)


@router.post("/deposit", response_model=DepositOut)
def create_deposit(request: DepositRequest, user_id: str = Depends(get_current_user_id)):
    if request.amount < 10:
        raise HTTPException(status_code=400, detail="O valor mínimo de depósito é R$ 10,00.")

    try:
        # 1. Obter a carteira (wallet) do usuário
        wallet_res = supabase.table("wallets").select("id").eq("user_id", user_id).execute()
        if not wallet_res.data:
            raise HTTPException(status_code=404, detail="Carteira do usuário não encontrada.")

        wallet_id = wallet_res.data[0]["id"]
        external_id = f"pix_{uuid.uuid4().hex[:12]}"

        # 2. Criar a transação pendente no banco
        transaction_data = {
            "wallet_id": wallet_id,
            "type": "deposit",
            "amount": request.amount,
            "status": "pending",
            "description": f"Depósito via Pix de R$ {request.amount:.2f}",
            "external_id": external_id
        }

        insert_res = supabase.table("transactions").insert(transaction_data).execute()
        if not insert_res.data:
            raise HTTPException(status_code=500, detail="Erro ao registrar transação no banco de dados.")

        # 3. Gerar payload Pix Copia e Cola simulado
        # Em produção, aqui seria feita a integração via API do gateway (ex: Asaas, Efí, etc.)
        pix_payload = f"00020101021226870014br.gov.bcb.pix2565qencooamttkhemyftsrz{external_id}5204000053039865405{request.amount:.2f}5802BR5913ArenaX1%20Ltda6009Sao%20Paulo62070503***6304"

        return {
            "transaction_id": insert_res.data[0]["id"],
            "external_id": external_id,
            "amount": request.amount,
            "copia_e_cola": pix_payload,
            "qr_code_url": f"https://api.qrserver.com/v1/create-qr-code/?size=300x300&data={pix_payload}"
        }

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Erro interno: {str(e)}")


@router.post("/webhook", response_model=WebhookOut)
def process_webhook(payload: WebhookPayload, x_webhook_secret: str = Header(default=None)):
    # Endpoint server-to-server (gateway -> backend): não usa JWT de usuário,
    # e sim um segredo compartilhado. Trocar por verificação de assinatura
    # própria do gateway (Asaas/Efí/etc.) ao integrar o provedor real.
    if not pix_webhook_secret or x_webhook_secret != pix_webhook_secret:
        raise HTTPException(status_code=401, detail="Assinatura do webhook inválida.")

    if payload.status != "completed":
        raise HTTPException(status_code=400, detail="Status de pagamento inválido no webhook.")

    try:
        result = supabase.rpc("fn_process_pix_deposit_webhook", {
            "p_external_id": payload.external_id,
            "p_amount": payload.amount,
        }).execute()
        return result.data
    except HTTPException:
        raise
    except Exception as e:
        _raise_from_rpc_error(e)


@router.post("/dev/simulate-deposit", response_model=WebhookOut)
def dev_simulate_deposit(payload: WebhookPayload, user_id: str = Depends(get_current_user_id)):
    """Endpoint só para desenvolvimento: confirma um depósito Pix pendente sem
    depender do gateway real. Nunca habilitar em produção — defina
    APP_ENV=production no .env para desativar automaticamente."""
    if os.getenv("APP_ENV", "development") == "production":
        raise HTTPException(status_code=404, detail="Não encontrado.")

    try:
        tx_res = supabase.table("transactions").select("wallet_id").eq("external_id", payload.external_id).execute()
        if not tx_res.data:
            raise HTTPException(status_code=404, detail="Transação não encontrada.")

        wallet_res = supabase.table("wallets").select("user_id").eq("id", tx_res.data[0]["wallet_id"]).execute()
        if not wallet_res.data or wallet_res.data[0]["user_id"] != user_id:
            raise HTTPException(status_code=403, detail="Você não pode confirmar esta transação.")

        result = supabase.rpc("fn_process_pix_deposit_webhook", {
            "p_external_id": payload.external_id,
            "p_amount": payload.amount,
        }).execute()
        return result.data
    except HTTPException:
        raise
    except Exception as e:
        _raise_from_rpc_error(e)


@router.post("/withdraw", response_model=WithdrawOut)
def create_withdraw(request: WithdrawRequest, user_id: str = Depends(get_current_user_id)):
    try:
        external_id = f"out_{uuid.uuid4().hex[:12]}"
        result = supabase.rpc("fn_withdraw", {
            "p_user_id": user_id,
            "p_amount": request.amount,
            "p_pix_key": request.pix_key,
            "p_external_id": external_id,
        }).execute()
        return result.data
    except HTTPException:
        raise
    except Exception as e:
        _raise_from_rpc_error(e)
