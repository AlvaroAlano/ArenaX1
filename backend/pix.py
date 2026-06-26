import os
import uuid
from fastapi import APIRouter, HTTPException, BackgroundTasks
from pydantic import BaseModel
from supabase import create_client, Client
from dotenv import load_dotenv

load_dotenv()

# Inicialização do Supabase Client com chave administrativa (service_role)
supabase_url = os.getenv("SUPABASE_URL")
supabase_service_key = os.getenv("SUPABASE_SERVICE_ROLE_KEY")

if not supabase_url or not supabase_service_key:
    raise ValueError("Variáveis de ambiente do Supabase não configuradas no Backend.")

supabase: Client = create_client(supabase_url, supabase_service_key)

router = APIRouter(prefix="/api/pix", tags=["Pix & Financeiro"])

# Schemas Pydantic
class DepositRequest(BaseModel):
    user_id: str
    amount: float

class WebhookPayload(BaseModel):
    external_id: str
    amount: float
    status: str  # 'completed' ou 'failed'

class WithdrawRequest(BaseModel):
    user_id: str
    amount: float
    pix_key: str


@router.post("/deposit")
def create_deposit(request: DepositRequest):
    if request.amount <= 0:
        raise HTTPException(status_code=400, detail="O valor do depósito deve ser maior que zero.")

    try:
        # 1. Obter a carteira (wallet) do usuário
        wallet_res = supabase.table("wallets").select("id").eq("user_id", request.user_id).execute()
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

    except Exception as e:
        if isinstance(e, HTTPException):
            raise e
        raise HTTPException(status_code=500, detail=f"Erro interno: {str(e)}")


@router.post("/webhook")
def process_webhook(payload: WebhookPayload):
    # Webhook idempotente para processamento do Pix do gateway
    if payload.status != "completed":
        raise HTTPException(status_code=400, detail="Status de pagamento inválido no webhook.")

    try:
        # 1. Buscar transação pelo external_id
        tx_res = supabase.table("transactions").select("*").eq("external_id", payload.external_id).execute()
        if not tx_res.data:
            raise HTTPException(status_code=404, detail="Transação correspondente não encontrada.")

        transaction = tx_res.data[0]

        # 2. Se já estiver concluída, apenas retornar sucesso (idempotência)
        if transaction["status"] == "completed":
            return {"status": "success", "message": "Transação já processada anteriormente (idempotente)."}

        wallet_id = transaction["wallet_id"]
        amount = float(transaction["amount"])

        # 3. Atualizar saldo da carteira do usuário (operação transacional de depósito)
        # Primeiro, buscamos o saldo atual
        wallet_res = supabase.table("wallets").select("balance").eq("id", wallet_id).execute()
        if not wallet_res.data:
            raise HTTPException(status_code=404, detail="Carteira associada não encontrada.")

        current_balance = float(wallet_res.data[0]["balance"])
        new_balance = current_balance + amount

        # Atualiza a carteira
        wallet_update = supabase.table("wallets").update({"balance": new_balance, "updated_at": "now()"}).eq("id", wallet_id).execute()
        if not wallet_update.data:
            raise HTTPException(status_code=500, detail="Falha ao atualizar o saldo da carteira.")

        # 4. Atualizar o status da transação para 'completed'
        tx_update = supabase.table("transactions").update({"status": "completed"}).eq("id", transaction["id"]).execute()
        if not tx_update.data:
            # Em produção, reverter o saldo atualizado se falhar a atualização da transação
            raise HTTPException(status_code=500, detail="Falha ao concluir o status da transação.")

        return {
            "status": "success", 
            "message": "Saldo atualizado com sucesso.",
            "new_balance": new_balance
        }

    except Exception as e:
        if isinstance(e, HTTPException):
            raise e
        raise HTTPException(status_code=500, detail=f"Erro interno no processamento do webhook: {str(e)}")


@router.post("/withdraw")
def create_withdraw(request: WithdrawRequest):
    if request.amount <= 0:
        raise HTTPException(status_code=400, detail="O valor de saque deve ser maior que zero.")

    try:
        # 1. Buscar a carteira do usuário
        wallet_res = supabase.table("wallets").select("*").eq("user_id", request.user_id).execute()
        if not wallet_res.data:
            raise HTTPException(status_code=404, detail="Carteira do usuário não encontrada.")

        wallet = wallet_res.data[0]
        wallet_id = wallet["id"]
        balance = float(wallet["balance"])

        if balance < request.amount:
            raise HTTPException(status_code=400, detail="Saldo insuficiente para realizar o saque.")

        # 2. Deduzir o valor da carteira
        new_balance = balance - request.amount
        wallet_update = supabase.table("wallets").update({"balance": new_balance, "updated_at": "now()"}).eq("id", wallet_id).execute()
        if not wallet_update.data:
            raise HTTPException(status_code=500, detail="Erro ao deduzir saldo da carteira.")

        # 3. Registrar a transação de saque concluída
        transaction_data = {
            "wallet_id": wallet_id,
            "type": "withdraw",
            "amount": -request.amount,  # Saque é registrado como valor negativo
            "status": "completed",
            "description": f"Saque via Pix enviado para chave: {request.pix_key}",
            "external_id": f"out_{uuid.uuid4().hex[:12]}"
        }
        
        insert_res = supabase.table("transactions").insert(transaction_data).execute()
        if not insert_res.data:
            raise HTTPException(status_code=500, detail="Erro ao registrar transação de saque.")

        return {
            "status": "success",
            "message": "Saque via Pix realizado e enviado para processamento bancário.",
            "amount": request.amount,
            "new_balance": new_balance
        }

    except Exception as e:
        if isinstance(e, HTTPException):
            raise e
        raise HTTPException(status_code=500, detail=f"Erro interno ao processar saque: {str(e)}")
