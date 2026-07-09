import os
from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel
from typing import List, Optional
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

router = APIRouter(prefix="/api/challenges", tags=["Lobby e Desafios"])

# Schemas Pydantic
class ChallengeCreateRequest(BaseModel):
    bet_amount: float
    platform: str  # 'PS5', 'Xbox', 'PC', 'Crossplay'
    game: str      # 'EA FC 25', 'EA FC 26', 'eFootball'

class ChallengeAcceptRequest(BaseModel):
    challenge_id: str

class ChallengeCancelRequest(BaseModel):
    challenge_id: str

class ChallengeReportRequest(BaseModel):
    challenge_id: str
    result: str  # 'win' ou 'loss'


# Schemas de resposta: fixam o contrato que o frontend consome, para um
# desalinhamento (ex.: nome de coluna trocado numa query) virar erro 500
# visível na hora, em vez de um campo `undefined` silencioso no client.
class ChallengeProfile(BaseModel):
    username: str
    fair_play_rating: float

class ChallengeRow(BaseModel):
    id: str
    creator_id: str
    opponent_id: Optional[str] = None
    bet_amount: float
    platform: str
    game: str
    status: str
    creator_result: Optional[str] = None
    opponent_result: Optional[str] = None
    winner_id: Optional[str] = None
    rake_amount: float = 0
    created_at: str
    updated_at: Optional[str] = None

class OpenChallengeOut(ChallengeRow):
    creator_profile: Optional[ChallengeProfile] = None

class MyChallengeOut(ChallengeRow):
    creator_profile: Optional[ChallengeProfile] = None
    opponent_profile: Optional[ChallengeProfile] = None

class ReportResultOut(BaseModel):
    message: str
    status: str
    winner_id: Optional[str] = None


def _raise_from_rpc_error(e: Exception):
    """As funções SQL levantam exceções no formato 'CODIGO: mensagem'.
    Mapeia isso para o HTTPException com status apropriado."""
    message = getattr(e, "message", None) or str(e)
    if "INSUFFICIENT_BALANCE" in message:
        status_code = 400
    elif "NOT_FOUND" in message:
        status_code = 404
    elif "FORBIDDEN" in message:
        status_code = 403
    elif any(code in message for code in (
        "CHALLENGE_NOT_OPEN", "SELF_ACCEPT", "CHALLENGE_NOT_IN_PROGRESS",
        "ALREADY_REPORTED", "INVALID_RESULT", "INVALID_AMOUNT"
    )):
        status_code = 400
    else:
        status_code = 500

    detail = message.split(": ", 1)[1] if ": " in message else message
    raise HTTPException(status_code=status_code, detail=detail)


@router.post("/create", response_model=ChallengeRow)
def create_challenge(request: ChallengeCreateRequest, user_id: str = Depends(get_current_user_id)):
    if request.bet_amount < 1:
        raise HTTPException(status_code=400, detail="O valor da partida precisa ser de pelo menos R$ 1,00.")

    try:
        result = supabase.rpc("fn_create_challenge", {
            "p_creator_id": user_id,
            "p_bet_amount": request.bet_amount,
            "p_platform": request.platform,
            "p_game": request.game,
        }).execute()
        return result.data
    except HTTPException:
        raise
    except Exception as e:
        _raise_from_rpc_error(e)


@router.get("/open", response_model=List[OpenChallengeOut])
def get_open_challenges():
    # Rota pública de propósito: o lobby de desafios abertos é vitrine para
    # visitantes não autenticados (gancho de cadastro), por isso não exige token.
    try:
        # Buscar desafios abertos com dados públicos do perfil do criador.
        # Alias precisa ser "creator_profile" para bater com o mesmo contrato
        # usado em /my-challenges (o frontend consome os dois com o mesmo tipo).
        challenges_res = supabase.table("challenges").select("*, creator_profile:creator_id(username, fair_play_rating)").eq("status", "open").execute()
        return challenges_res.data or []
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Erro ao buscar desafios abertos: {str(e)}")


@router.post("/accept", response_model=ChallengeRow)
def accept_challenge(request: ChallengeAcceptRequest, user_id: str = Depends(get_current_user_id)):
    try:
        result = supabase.rpc("fn_accept_challenge", {
            "p_challenge_id": request.challenge_id,
            "p_opponent_id": user_id,
        }).execute()
        return result.data
    except HTTPException:
        raise
    except Exception as e:
        _raise_from_rpc_error(e)


@router.post("/cancel", response_model=ChallengeRow)
def cancel_challenge(request: ChallengeCancelRequest, user_id: str = Depends(get_current_user_id)):
    # Só cancela (nunca edita) um desafio ainda aberto — editar valor/plataforma
    # em cima de uma aposta que outro jogador pode aceitar a qualquer instante
    # criaria uma corrida real entre o dono editando e alguém aceitando o valor antigo.
    try:
        result = supabase.rpc("fn_cancel_challenge", {
            "p_challenge_id": request.challenge_id,
            "p_user_id": user_id,
        }).execute()
        return result.data
    except HTTPException:
        raise
    except Exception as e:
        _raise_from_rpc_error(e)


@router.get("/my-challenges", response_model=List[MyChallengeOut])
def get_my_challenges(user_id: str = Depends(get_current_user_id)):
    try:
        # Buscar desafios onde o usuário seja criador ou oponente
        challenges_res = supabase.table("challenges").select(
            "*, creator_profile:creator_id(username, fair_play_rating), opponent_profile:opponent_id(username, fair_play_rating)"
        ).or_(f"creator_id.eq.{user_id},opponent_id.eq.{user_id}").order("created_at", desc=True).execute()

        return challenges_res.data or []
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Erro ao carregar seus desafios: {str(e)}")


@router.post("/report", response_model=ReportResultOut)
def report_challenge_result(request: ChallengeReportRequest, user_id: str = Depends(get_current_user_id)):
    if request.result not in ["win", "loss"]:
        raise HTTPException(status_code=400, detail="Resultado inválido. Deve ser 'win' ou 'loss'.")

    try:
        result = supabase.rpc("fn_report_challenge_result", {
            "p_challenge_id": request.challenge_id,
            "p_user_id": user_id,
            "p_result": request.result,
        }).execute()
        return result.data
    except HTTPException:
        raise
    except Exception as e:
        _raise_from_rpc_error(e)
