import os
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import Optional
from supabase import create_client, Client
from dotenv import load_dotenv

load_dotenv()

# Inicialização do Supabase Client com chave administrativa (service_role)
supabase_url = os.getenv("SUPABASE_URL")
supabase_service_key = os.getenv("SUPABASE_SERVICE_ROLE_KEY")

if not supabase_url or not supabase_service_key:
    raise ValueError("Variáveis de ambiente do Supabase não configuradas no Backend.")

supabase: Client = create_client(supabase_url, supabase_service_key)

router = APIRouter(prefix="/api/challenges", tags=["Lobby e Desafios"])

# Schemas Pydantic
class ChallengeCreateRequest(BaseModel):
    creator_id: str
    bet_amount: float
    platform: str  # 'PS5', 'Xbox', 'PC', 'Crossplay'
    game: str      # 'EA FC 25', 'eFootball'

class ChallengeAcceptRequest(BaseModel):
    challenge_id: str
    opponent_id: str

class ChallengeReportRequest(BaseModel):
    challenge_id: str
    user_id: str
    result: str  # 'win' ou 'loss'

@router.post("/create")
def create_challenge(request: ChallengeCreateRequest):
    if request.bet_amount < 0:
        raise HTTPException(status_code=400, detail="O valor da aposta não pode ser negativo.")

    try:
        # 1. Buscar a carteira do criador
        wallet_res = supabase.table("wallets").select("*").eq("user_id", request.creator_id).execute()
        if not wallet_res.data:
            raise HTTPException(status_code=404, detail="Carteira do criador não encontrada.")

        wallet = wallet_res.data[0]
        wallet_id = wallet["id"]
        balance = float(wallet["balance"])
        locked_balance = float(wallet["locked_balance"])

        # 2. Verificar se há saldo disponível suficiente
        if balance < request.bet_amount:
            raise HTTPException(status_code=400, detail="Saldo insuficiente para abrir este desafio.")

        # 3. Executar o congelamento do saldo (Bet Freeze)
        new_balance = balance - request.bet_amount
        new_locked = locked_balance + request.bet_amount

        # Atualizar carteira no banco
        wallet_update = supabase.table("wallets").update({
            "balance": new_balance,
            "locked_balance": new_locked,
            "updated_at": "now()"
        }).eq("id", wallet_id).execute()

        if not wallet_update.data:
            raise HTTPException(status_code=500, detail="Erro ao congelar saldo para aposta.")

        # 4. Criar o registro do Desafio
        challenge_data = {
            "creator_id": request.creator_id,
            "bet_amount": request.bet_amount,
            "platform": request.platform,
            "game": request.game,
            "status": "open"
        }
        challenge_res = supabase.table("challenges").insert(challenge_data).execute()
        if not challenge_res.data:
            # Em produção, reverter o congelamento do saldo se a criação da sala falhar
            raise HTTPException(status_code=500, detail="Erro ao criar a sala de desafio.")

        challenge_id = challenge_res.data[0]["id"]

        # 5. Registrar transação de bloqueio de saldo (bet_freeze)
        tx_data = {
            "wallet_id": wallet_id,
            "type": "bet_freeze",
            "amount": -request.bet_amount,
            "status": "completed",
            "description": f"Saldo congelado para desafio X1 (Sala: {challenge_id[:8]})"
        }
        supabase.table("transactions").insert(tx_data).execute()

        return challenge_res.data[0]

    except Exception as e:
        if isinstance(e, HTTPException):
            raise e
        raise HTTPException(status_code=500, detail=f"Erro ao criar desafio: {str(e)}")


@router.get("/open")
def get_open_challenges():
    try:
        # Buscar desafios abertos com dados públicos do perfil do criador
        challenges_res = supabase.table("challenges").select("*, profiles:creator_id(username, fair_play_rating)").eq("status", "open").execute()
        return challenges_res.data or []
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Erro ao buscar desafios abertos: {str(e)}")


@router.post("/accept")
def accept_challenge(request: ChallengeAcceptRequest):
    try:
        # 1. Buscar o desafio correspondente
        challenge_res = supabase.table("challenges").select("*").eq("id", request.challenge_id).execute()
        if not challenge_res.data:
            raise HTTPException(status_code=404, detail="Desafio não encontrado.")

        challenge = challenge_res.data[0]

        if challenge["status"] != "open":
            raise HTTPException(status_code=400, detail="Este desafio não está mais aberto para aceitação.")

        if challenge["creator_id"] == request.opponent_id:
            raise HTTPException(status_code=400, detail="Você não pode aceitar seu próprio desafio.")

        bet_amount = float(challenge["bet_amount"])

        # 2. Buscar a carteira do oponente
        wallet_res = supabase.table("wallets").select("*").eq("user_id", request.opponent_id).execute()
        if not wallet_res.data:
            raise HTTPException(status_code=404, detail="Carteira do oponente não encontrada.")

        wallet = wallet_res.data[0]
        wallet_id = wallet["id"]
        balance = float(wallet["balance"])
        locked_balance = float(wallet["locked_balance"])

        # 3. Verificar saldo disponível do oponente
        if balance < bet_amount:
            raise HTTPException(status_code=400, detail="Saldo insuficiente para aceitar esta aposta.")

        # 4. Executar congelamento do saldo do oponente
        new_balance = balance - bet_amount
        new_locked = locked_balance + bet_amount

        # Atualizar a carteira do oponente
        wallet_update = supabase.table("wallets").update({
            "balance": new_balance,
            "locked_balance": new_locked,
            "updated_at": "now()"
        }).eq("id", wallet_id).execute()

        if not wallet_update.data:
            raise HTTPException(status_code=500, detail="Erro ao congelar saldo para aceitar aposta.")

        # 5. Atualizar status da partida para in_progress e salvar o opponent_id
        challenge_update = supabase.table("challenges").update({
            "opponent_id": request.opponent_id,
            "status": "in_progress",
            "updated_at": "now()"
        }).eq("id", request.challenge_id).execute()

        if not challenge_update.data:
            # Em produção, fazer rollback do saldo do oponente
            raise HTTPException(status_code=500, detail="Erro ao atualizar status da partida.")

        # 6. Registrar transação de bloqueio de saldo do oponente (bet_freeze)
        tx_data = {
            "wallet_id": wallet_id,
            "type": "bet_freeze",
            "amount": -bet_amount,
            "status": "completed",
            "description": f"Saldo congelado para desafio X1 (Sala: {request.challenge_id[:8]})"
        }
        supabase.table("transactions").insert(tx_data).execute()

        return challenge_update.data[0]

    except Exception as e:
        if isinstance(e, HTTPException):
            raise e
        raise HTTPException(status_code=500, detail=f"Erro ao aceitar desafio: {str(e)}")


@router.get("/my-challenges")
def get_my_challenges(user_id: str):
    try:
        # Buscar desafios onde o usuário seja criador ou oponente
        challenges_res = supabase.table("challenges").select(
            "*, creator_profile:creator_id(username, fair_play_rating), opponent_profile:opponent_id(username, fair_play_rating)"
        ).or_(f"creator_id.eq.{user_id},opponent_id.eq.{user_id}").order("created_at", {"ascending": False}).execute()
        
        return challenges_res.data or []
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Erro ao carregar seus desafios: {str(e)}")


@router.post("/report")
def report_challenge_result(request: ChallengeReportRequest):
    if request.result not in ["win", "loss"]:
        raise HTTPException(status_code=400, detail="Resultado inválido. Deve ser 'win' ou 'loss'.")

    try:
        # 1. Buscar o desafio
        challenge_res = supabase.table("challenges").select("*").eq("id", request.challenge_id).execute()
        if not challenge_res.data:
            raise HTTPException(status_code=404, detail="Desafio não encontrado.")

        challenge = challenge_res.data[0]

        if challenge["status"] != "in_progress":
            raise HTTPException(status_code=400, detail="Este desafio não está em andamento.")

        is_creator = (challenge["creator_id"] == request.user_id)
        is_opponent = (challenge["opponent_id"] == request.user_id)

        if not is_creator and not is_opponent:
            raise HTTPException(status_code=403, detail="Você não faz parte deste desafio.")

        # 2. Atualizar o resultado do usuário
        update_data = {}
        if is_creator:
            if challenge.get("creator_result"):
                raise HTTPException(status_code=400, detail="Você já reportou o resultado.")
            update_data["creator_result"] = request.result
            challenge["creator_result"] = request.result
        else:
            if challenge.get("opponent_result"):
                raise HTTPException(status_code=400, detail="Você já reportou o resultado.")
            update_data["opponent_result"] = request.result
            challenge["opponent_result"] = request.result

        # Update parcial
        supabase.table("challenges").update(update_data).eq("id", request.challenge_id).execute()

        # 3. Verificar se ambos reportaram
        c_res = challenge.get("creator_result")
        o_res = challenge.get("opponent_result")

        # Se ambos reportaram (o que acabou de ser atualizado também está em 'challenge')
        if c_res and o_res:
            # Consenso: um ganhou, outro perdeu
            if (c_res == "win" and o_res == "loss") or (c_res == "loss" and o_res == "win"):
                winner_id = challenge["creator_id"] if c_res == "win" else challenge["opponent_id"]
                loser_id = challenge["opponent_id"] if c_res == "win" else challenge["creator_id"]

                bet_amount = float(challenge["bet_amount"])
                rake_percentage = 0.10
                prize_pool = bet_amount * 2
                platform_fee = prize_pool * rake_percentage
                winner_prize = prize_pool - platform_fee

                # Pegar carteiras
                wallets_res = supabase.table("wallets").select("*").in_("user_id", [winner_id, loser_id]).execute()
                winner_wallet = next(w for w in wallets_res.data if w["user_id"] == winner_id)
                loser_wallet = next(w for w in wallets_res.data if w["user_id"] == loser_id)

                # Liberar locked_balance de ambos (remove bet_amount)
                # Adicionar winner_prize ao balance do vencedor
                supabase.table("wallets").update({
                    "balance": float(winner_wallet["balance"]) + winner_prize,
                    "locked_balance": float(winner_wallet["locked_balance"]) - bet_amount,
                    "updated_at": "now()"
                }).eq("id", winner_wallet["id"]).execute()

                supabase.table("wallets").update({
                    "locked_balance": float(loser_wallet["locked_balance"]) - bet_amount,
                    "updated_at": "now()"
                }).eq("id", loser_wallet["id"]).execute()

                # Criar transações
                supabase.table("transactions").insert([
                    {
                        "wallet_id": winner_wallet["id"],
                        "type": "challenge_win",
                        "amount": winner_prize,
                        "status": "completed",
                        "description": f"Vitória no desafio (Sala: {request.challenge_id[:8]})"
                    },
                    {
                        "wallet_id": loser_wallet["id"],
                        "type": "challenge_loss",
                        "amount": -bet_amount,
                        "status": "completed",
                        "description": f"Derrota no desafio (Sala: {request.challenge_id[:8]})"
                    }
                ]).execute()

                # Atualizar status da sala
                supabase.table("challenges").update({
                    "status": "completed",
                    "winner_id": winner_id,
                    "updated_at": "now()"
                }).eq("id", request.challenge_id).execute()

                return {"message": "Resultado confirmado com consenso.", "status": "completed", "winner_id": winner_id}

            else:
                # Divergência (ambos win ou ambos loss)
                supabase.table("challenges").update({
                    "status": "disputed",
                    "updated_at": "now()"
                }).eq("id", request.challenge_id).execute()

                # Criar registro na tabela de disputas
                supabase.table("disputes").insert({
                    "challenge_id": request.challenge_id,
                    "status": "open"
                }).execute()

                return {"message": "Divergência de resultados. Partida em disputa.", "status": "disputed"}

        return {"message": "Resultado reportado. Aguardando oponente.", "status": "waiting"}

    except Exception as e:
        if isinstance(e, HTTPException):
            raise e
        raise HTTPException(status_code=500, detail=f"Erro ao reportar resultado: {str(e)}")
