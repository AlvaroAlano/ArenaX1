import hashlib
import hmac
import os
import re
import time
import uuid
from typing import Optional

import httpx
from fastapi import APIRouter, HTTPException, Depends, Header, Request
from pydantic import BaseModel
from supabase import create_client, Client
from dotenv import load_dotenv

from auth import get_current_user_id

load_dotenv()

# Inicialização do Supabase Client com chave administrativa (service_role)
supabase_url = os.getenv("SUPABASE_URL")
supabase_service_key = os.getenv("SUPABASE_SERVICE_ROLE_KEY")

if not supabase_url or not supabase_service_key:
    raise ValueError("Variáveis de ambiente do Supabase não configuradas no Backend.")

supabase: Client = create_client(supabase_url, supabase_service_key)

# Mercado Pago — depósito via Pix (recebimento). A API pública deles não
# manda Pix pra chave de terceiro, então o saque (seção mais abaixo) NÃO
# passa por aqui — fica pendente e um admin processa manualmente
# (backend/admin.py, fn_confirm_withdraw/fn_reject_withdraw).
MERCADO_PAGO_ACCESS_TOKEN = os.getenv("MERCADO_PAGO_ACCESS_TOKEN")
MERCADO_PAGO_WEBHOOK_SECRET = os.getenv("MERCADO_PAGO_WEBHOOK_SECRET")
BACKEND_PUBLIC_URL = os.getenv("BACKEND_PUBLIC_URL")

# Taxa de depósito (termos-de-uso.md, cláusula 4.4): somada ao valor pedido
# — quem pede depositar R$50 paga R$50,99 no Pix, e R$50,00 caem na carteira.
DEPOSIT_FEE = 0.99

_mp_client = httpx.Client(
    base_url="https://api.mercadopago.com",
    headers={"Authorization": f"Bearer {MERCADO_PAGO_ACCESS_TOKEN}"},
    timeout=15.0,
)

router = APIRouter(prefix="/api/pix", tags=["Pix & Financeiro"])


# Schemas Pydantic
class DepositRequest(BaseModel):
    amount: float


class WebhookPayload(BaseModel):
    """Usado só pelo /dev/simulate-deposit — o /webhook real lê o corpo cru
    (formato próprio do Mercado Pago), não este schema."""
    external_id: str
    amount: float
    status: str  # 'completed' ou 'failed'


class WithdrawRequest(BaseModel):
    amount: float
    pix_key: str


_EMAIL_RE = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")
_UUID_RE = re.compile(r"^[0-9a-fA-F]{8}-?[0-9a-fA-F]{4}-?[0-9a-fA-F]{4}-?[0-9a-fA-F]{4}-?[0-9a-fA-F]{12}$")


def _normalize_pix_key(raw: str) -> str:
    """Valida e normaliza uma chave Pix contra os 5 tipos oficiais (CPF, CNPJ,
    telefone, e-mail, chave aleatória/EVP). Como o saque é processado à mão por
    um admin, uma chave vazia ou lixo trava o pagamento de um valor já debitado
    (ACHADO-06). Levanta ValueError com mensagem amigável se não bater com
    nenhum formato conhecido."""
    key = (raw or "").strip()
    if not key:
        raise ValueError("Informe a chave Pix para o saque.")
    if len(key) > 140:
        raise ValueError("Chave Pix inválida (muito longa).")

    # E-mail
    if _EMAIL_RE.match(key):
        return key.lower()
    # Chave aleatória (EVP) — UUID com ou sem hifens
    if _UUID_RE.match(key):
        return key.lower()

    digits = re.sub(r"\D", "", key)
    # CPF (11) ou CNPJ (14) — devolve só os dígitos
    if len(digits) in (11, 14) and digits == re.sub(r"[.\-/\s]", "", key):
        return digits
    # Telefone celular BR: +55 + DDD + 9 dígitos (12 ou 13 dígitos no total),
    # aceitando com ou sem o +55 digitado.
    if key.startswith("+") and 12 <= len(digits) <= 13:
        return "+" + digits
    if len(digits) in (10, 11) and digits == re.sub(r"[()\-\s]", "", key):
        return "+55" + digits

    raise ValueError(
        "Chave Pix inválida. Use CPF, CNPJ, e-mail, telefone ou chave aleatória."
    )


# Schemas de resposta: fixam o contrato consumido pelo frontend.
class DepositOut(BaseModel):
    transaction_id: str
    external_id: str
    requested_amount: float
    fee_amount: float
    total_amount: float
    copia_e_cola: str
    qr_code_base64: str


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
    elif "AMOUNT_MISMATCH" in message or "INVALID_AMOUNT" in message or "INVALID_STATUS" in message:
        status_code = 400
    else:
        status_code = 500

    detail = message.split(": ", 1)[1] if ": " in message else message
    raise HTTPException(status_code=status_code, detail=detail)


# PNG 1x1 transparente — só pra o <img> do QR não quebrar no mock de dev.
_DEV_QR_PNG_BASE64 = (
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="
)


@router.post("/deposit", response_model=DepositOut)
def create_deposit(request: DepositRequest, user_id: str = Depends(get_current_user_id)):
    if request.amount < 10:
        raise HTTPException(status_code=400, detail="O valor mínimo de depósito é R$ 10,00.")

    is_production = os.getenv("APP_ENV", "development") == "production"
    use_mp = bool(MERCADO_PAGO_ACCESS_TOKEN and BACKEND_PUBLIC_URL)

    if is_production and not use_mp:
        raise HTTPException(status_code=503, detail="Depósito via Pix temporariamente indisponível. Tente novamente em instantes.")

    try:
        # 1. Obter a carteira (wallet) do usuário
        wallet_res = supabase.table("wallets").select("id").eq("user_id", user_id).execute()
        if not wallet_res.data:
            raise HTTPException(status_code=404, detail="Carteira do usuário não encontrada.")

        wallet_id = wallet_res.data[0]["id"]
        local_ref = f"pix_{uuid.uuid4().hex[:12]}"

        fee = DEPOSIT_FEE
        total_charged = round(request.amount + fee, 2)

        if use_mp:
            # 2. E-mail do pagador — exigido pela API de pagamentos do Mercado Pago
            try:
                user_res = supabase.auth.admin.get_user_by_id(user_id)
                payer_email = user_res.user.email
            except Exception:
                payer_email = None
            if not payer_email:
                raise HTTPException(status_code=500, detail="Não foi possível obter o e-mail da conta para gerar o Pix.")

            # 3. Criar o pagamento Pix de verdade no Mercado Pago
            mp_res = _mp_client.post(
                "/v1/payments",
                json={
                    "transaction_amount": total_charged,
                    "payment_method_id": "pix",
                    "payer": {"email": payer_email},
                    "external_reference": local_ref,
                    "notification_url": f"{BACKEND_PUBLIC_URL}/api/pix/webhook",
                    "description": f"Depósito ArenaX1 — R$ {request.amount:.2f} + taxa de R$ {fee:.2f}",
                },
                headers={"X-Idempotency-Key": local_ref},
            )
            if mp_res.status_code >= 300:
                print(f"[MP ERROR] POST /v1/payments status={mp_res.status_code} body={mp_res.text}")
                raise HTTPException(status_code=502, detail="Não foi possível gerar a cobrança Pix agora. Tente novamente em instantes.")

            mp_payment = mp_res.json()
            payment_external_id = str(mp_payment["id"])
            transaction_data = mp_payment.get("point_of_interaction", {}).get("transaction_data", {})
            copia_e_cola = transaction_data.get("qr_code")
            qr_code_base64 = transaction_data.get("qr_code_base64")
            if not copia_e_cola or not qr_code_base64:
                print(f"[MP ERROR] resposta sem QR Code: {mp_payment}")
                raise HTTPException(status_code=502, detail="O Mercado Pago não retornou o QR Code Pix. Tente novamente.")
            gateway = "mercadopago"
        else:
            # Dev sem token do Mercado Pago: gera cobrança mock com a mesma
            # estrutura (taxa + total) pra testar UI e /dev/simulate-deposit.
            payment_external_id = local_ref
            copia_e_cola = (
                f"00020126580014BR.GOV.BCB.PIX0136{local_ref}"
                f"520400005303986540{total_charged:.2f}5802BR5913ARENAX1 DEV6009SAO PAULO62070503***6304ABCD"
            )
            qr_code_base64 = _DEV_QR_PNG_BASE64
            gateway = "dev_mock"

        # 4. Criar a transação pendente no banco.
        # Com MP real, external_id = id do pagamento no Mercado Pago (o que o
        # webhook e o GET /v1/payments/{id} devolvem). Em mock, usa o local_ref.
        transaction_data_row = {
            "wallet_id": wallet_id,
            "type": "deposit",
            "amount": total_charged,
            "fee_amount": fee,
            "status": "pending",
            "gateway": gateway,
            "description": f"Depósito via Pix de R$ {request.amount:.2f} (+ taxa de R$ {fee:.2f})",
            "external_id": payment_external_id,
        }

        insert_res = supabase.table("transactions").insert(transaction_data_row).execute()
        if not insert_res.data:
            raise HTTPException(status_code=500, detail="Erro ao registrar transação no banco de dados.")

        return {
            "transaction_id": insert_res.data[0]["id"],
            "external_id": payment_external_id,
            "requested_amount": request.amount,
            "fee_amount": fee,
            "total_amount": total_charged,
            "copia_e_cola": copia_e_cola,
            "qr_code_base64": qr_code_base64,
        }

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Erro interno: {str(e)}")


def _verify_mp_signature(request_id: Optional[str], x_signature: Optional[str], data_id: Optional[str]) -> bool:
    """Verifica a assinatura do webhook do Mercado Pago.

    Formato documentado: header x-signature vem como "ts=<timestamp>,v1=<hash>".
    O hash é HMAC-SHA256 de um manifest "id:{data_id};request-id:{request_id};ts:{ts};"
    usando o segredo configurado no painel de integrações do Mercado Pago.
    """
    if not MERCADO_PAGO_WEBHOOK_SECRET or not x_signature or not data_id:
        return False

    parts = dict(p.split("=", 1) for p in x_signature.split(",") if "=" in p)
    ts = parts.get("ts")
    received_hash = parts.get("v1")
    if not ts or not received_hash:
        return False

    manifest = f"id:{data_id};request-id:{request_id or ''};ts:{ts};"
    expected_hash = hmac.new(
        MERCADO_PAGO_WEBHOOK_SECRET.encode(), manifest.encode(), hashlib.sha256
    ).hexdigest()

    return hmac.compare_digest(expected_hash, received_hash)


@router.post("/webhook")
async def process_webhook(
    request: Request,
    x_signature: str = Header(default=None),
    x_request_id: str = Header(default=None),
):
    # Endpoint server-to-server (Mercado Pago -> backend): autenticado pela
    # assinatura HMAC própria do gateway, não por JWT de usuário.
    body = await request.json()
    data_id = str(body.get("data", {}).get("id") or request.query_params.get("data.id") or "")

    if not _verify_mp_signature(x_request_id, x_signature, data_id):
        raise HTTPException(status_code=401, detail="Assinatura do webhook inválida.")

    if body.get("type") != "payment" or not data_id:
        # Notificação de outro tipo de evento (ex: merchant_order) — ignora.
        return {"status": "ignored"}

    # Nunca confia em valor/status vindos do corpo do webhook — busca o
    # pagamento de verdade na API do Mercado Pago antes de creditar.
    mp_res = _mp_client.get(f"/v1/payments/{data_id}")
    if mp_res.status_code >= 300:
        raise HTTPException(status_code=502, detail="Não foi possível confirmar o pagamento no Mercado Pago.")

    mp_payment = mp_res.json()
    if mp_payment.get("status") != "approved":
        return {"status": "ignored"}

    try:
        result = supabase.rpc("fn_process_pix_deposit_webhook", {
            "p_external_id": data_id,
            "p_amount": mp_payment.get("transaction_amount"),
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
        pix_key = _normalize_pix_key(request.pix_key)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

    try:
        external_id = f"out_{uuid.uuid4().hex[:12]}"
        result = supabase.rpc("fn_withdraw", {
            "p_user_id": user_id,
            "p_amount": request.amount,
            "p_pix_key": pix_key,
            "p_external_id": external_id,
        }).execute()
        return result.data
    except HTTPException:
        raise
    except Exception as e:
        _raise_from_rpc_error(e)
