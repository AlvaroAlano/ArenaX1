import os
from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel
from typing import List, Optional
from supabase import create_client, Client
from dotenv import load_dotenv

from auth import get_current_user_id, get_current_admin_user_id
from catalog import validate_platform_and_game

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

class ChallengeJoinRequest(BaseModel):
    challenge_id: str

class ChallengeJoinRequestAction(BaseModel):
    request_id: str

class ChallengeCancelRequest(BaseModel):
    challenge_id: str

class ChallengeMarkReadyRequest(BaseModel):
    challenge_id: str

class ChallengeReportRequest(BaseModel):
    challenge_id: str
    result: str  # 'win' ou 'loss'

class ChallengeDisputeRequest(BaseModel):
    challenge_id: str
    reason: str
    details: Optional[str] = None

class ChallengeResolveRequest(BaseModel):
    challenge_id: str
    winner_id: str


# Schemas de resposta: fixam o contrato que o frontend consome, para um
# desalinhamento (ex.: nome de coluna trocado numa query) virar erro 500
# visível na hora, em vez de um campo `undefined` silencioso no client.
class ChallengeProfile(BaseModel):
    username: str
    fair_play_rating: float

class JoinRequestOut(BaseModel):
    id: str
    challenge_id: str
    requester_id: str
    status: str
    created_at: str
    requester_profile: Optional[ChallengeProfile] = None

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
    settlement_release_at: Optional[str] = None
    created_at: str
    updated_at: Optional[str] = None

class OpenChallengeOut(ChallengeRow):
    creator_profile: Optional[ChallengeProfile] = None

class MyChallengeOut(ChallengeRow):
    creator_profile: Optional[ChallengeProfile] = None
    opponent_profile: Optional[ChallengeProfile] = None
    join_requests: List[JoinRequestOut] = []

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
        "CHALLENGE_NOT_OPEN", "CHALLENGE_NOT_IN_PROGRESS", "CHALLENGE_NOT_ACCEPTED",
        "ALREADY_REPORTED", "INVALID_RESULT", "INVALID_AMOUNT",
        "SELF_REQUEST", "ALREADY_REQUESTED", "REQUEST_NOT_PENDING",
        "CANNOT_DISPUTE", "CHALLENGE_NOT_DISPUTED", "INVALID_WINNER"
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
        validate_platform_and_game(request.platform, request.game)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

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
        # deactivated_at vem no embed só para filtrar: quem desativou a conta
        # some da vitrine (o response_model descarta esse campo extra).
        challenges_res = supabase.table("challenges").select("*, creator_profile:creator_id(username, fair_play_rating, deactivated_at)").eq("status", "open").execute()
        rows = challenges_res.data or []
        return [c for c in rows if not (c.get("creator_profile") or {}).get("deactivated_at")]
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Erro ao buscar desafios abertos: {str(e)}")


@router.post("/request-join", response_model=JoinRequestOut)
def request_join_challenge(request: ChallengeJoinRequest, user_id: str = Depends(get_current_user_id)):
    try:
        result = supabase.rpc("fn_request_join_challenge", {
            "p_challenge_id": request.challenge_id,
            "p_requester_id": user_id,
        }).execute()
        return result.data
    except HTTPException:
        raise
    except Exception as e:
        _raise_from_rpc_error(e)


@router.post("/accept-join-request", response_model=ChallengeRow)
def accept_join_request(request: ChallengeJoinRequestAction, user_id: str = Depends(get_current_user_id)):
    try:
        result = supabase.rpc("fn_accept_join_request", {
            "p_request_id": request.request_id,
            "p_creator_id": user_id,
        }).execute()
        return result.data
    except HTTPException:
        raise
    except Exception as e:
        _raise_from_rpc_error(e)


@router.post("/reject-join-request", response_model=JoinRequestOut)
def reject_join_request(request: ChallengeJoinRequestAction, user_id: str = Depends(get_current_user_id)):
    try:
        result = supabase.rpc("fn_reject_join_request", {
            "p_request_id": request.request_id,
            "p_creator_id": user_id,
        }).execute()
        return result.data
    except HTTPException:
        raise
    except Exception as e:
        _raise_from_rpc_error(e)


@router.post("/cancel-join-request", response_model=JoinRequestOut)
def cancel_join_request(request: ChallengeJoinRequestAction, user_id: str = Depends(get_current_user_id)):
    try:
        result = supabase.rpc("fn_cancel_join_request", {
            "p_request_id": request.request_id,
            "p_requester_id": user_id,
        }).execute()
        return result.data
    except HTTPException:
        raise
    except Exception as e:
        _raise_from_rpc_error(e)


@router.get("/my-join-requests", response_model=List[JoinRequestOut])
def get_my_join_requests(user_id: str = Depends(get_current_user_id)):
    try:
        requests_res = supabase.table("challenge_join_requests").select("*").eq("requester_id", user_id).execute()
        return requests_res.data or []
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Erro ao carregar suas solicitações: {str(e)}")


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
            "*, creator_profile:creator_id(username, fair_play_rating), opponent_profile:opponent_id(username, fair_play_rating), "
            "join_requests:challenge_join_requests(id, challenge_id, requester_id, status, created_at, requester_profile:requester_id(username, fair_play_rating))"
        ).or_(f"creator_id.eq.{user_id},opponent_id.eq.{user_id}").order("created_at", desc=True).execute()

        return challenges_res.data or []
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Erro ao carregar seus desafios: {str(e)}")


@router.post("/mark-ready", response_model=ChallengeRow)
def mark_ready(request: ChallengeMarkReadyRequest, user_id: str = Depends(get_current_user_id)):
    # Checkpoint "Iniciar partida": confirma presença na fase 'accepted'. Quando
    # os dois confirmam, a função SQL move pra 'in_progress' e arma o prazo.
    try:
        result = supabase.rpc("fn_mark_ready", {
            "p_challenge_id": request.challenge_id,
            "p_user_id": user_id,
        }).execute()
        return result.data
    except HTTPException:
        raise
    except Exception as e:
        _raise_from_rpc_error(e)


@router.post("/process-timeouts")
def process_match_timeouts(user_id: str = Depends(get_current_admin_user_id)):
    # Gatilho manual do job de timeout (o agendamento normal é via pg_cron, ver
    # 24_match_absent_player.sql). Admin-only — útil pra testar ou se o pg_cron
    # não estiver disponível no plano.
    try:
        result = supabase.rpc("fn_process_match_timeouts", {}).execute()
        return result.data
    except HTTPException:
        raise
    except Exception as e:
        _raise_from_rpc_error(e)


@router.post("/open-dispute", response_model=ChallengeRow)
def open_challenge_dispute(request: ChallengeDisputeRequest, user_id: str = Depends(get_current_user_id)):
    # Contestação reativa (resultado aceito automático, dentro da janela de 3d)
    # ou reporte de problema na partida em andamento (má conduta/trapaça).
    try:
        result = supabase.rpc("fn_open_challenge_dispute", {
            "p_challenge_id": request.challenge_id,
            "p_user_id": user_id,
            "p_reason": request.reason,
            "p_details": request.details,
        }).execute()
        return result.data
    except HTTPException:
        raise
    except Exception as e:
        _raise_from_rpc_error(e)


@router.post("/resolve-dispute", response_model=ChallengeRow)
def resolve_challenge_dispute(request: ChallengeResolveRequest, admin_id: str = Depends(get_current_admin_user_id)):
    # Resolução de disputa de desafio 1v1 (admin) — decide o vencedor, normaliza
    # o dinheiro e paga; penaliza o fair_play só de quem mentiu.
    try:
        result = supabase.rpc("fn_resolve_challenge_dispute", {
            "p_challenge_id": request.challenge_id,
            "p_winner_id": request.winner_id,
        }).execute()
        return result.data
    except HTTPException:
        raise
    except Exception as e:
        _raise_from_rpc_error(e)


@router.post("/release-settlements")
def release_settlements(admin_id: str = Depends(get_current_admin_user_id)):
    # Gatilho manual da liberação de prêmios retidos (o normal é pg_cron horário,
    # ver 26_match_settlement_hold.sql). Admin-only.
    try:
        result = supabase.rpc("fn_release_due_settlements", {}).execute()
        return result.data
    except HTTPException:
        raise
    except Exception as e:
        _raise_from_rpc_error(e)


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
