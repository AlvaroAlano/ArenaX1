import os
from datetime import datetime
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

router = APIRouter(prefix="/api/tournaments", tags=["Torneios"])


# Schemas Pydantic — request
class TournamentCreateRequest(BaseModel):
    title: str
    game: str  # 'EA FC 25', 'EA FC 26', 'eFootball'
    max_players: int  # 4, 8 ou 16
    participant_names: List[str]
    randomize_teams: bool = False
    team_names: Optional[List[str]] = None


class SubmitMatchResultRequest(BaseModel):
    tournament_id: str
    match_id: str
    score_a: int
    score_b: int


# Schemas Pydantic — resposta: fixam o contrato que o frontend consome, para
# um desalinhamento (ex.: nome de coluna trocado numa query) virar erro 500
# visível na hora, em vez de um campo `undefined` silencioso no client.
class TournamentParticipantOut(BaseModel):
    id: str
    display_name: str
    team_name: Optional[str] = None
    bracket_seed: int


class TournamentMatchOut(BaseModel):
    id: str
    round: int
    slot: int
    participant_a_id: Optional[str] = None
    participant_b_id: Optional[str] = None
    score_a: Optional[int] = None
    score_b: Optional[int] = None
    winner_participant_id: Optional[str] = None
    status: str


class TournamentRow(BaseModel):
    id: str
    host_id: str
    title: str
    game: str
    format: str
    max_players: int
    status: str
    champion_participant_id: Optional[str] = None
    created_at: str
    completed_at: Optional[str] = None


class TournamentDetailOut(TournamentRow):
    participants: List[TournamentParticipantOut]
    matches: List[TournamentMatchOut]


class TournamentSummaryOut(BaseModel):
    id: str
    title: str
    game: str
    max_players: int
    status: str
    champion_participant_id: Optional[str] = None
    created_at: str
    completed_at: Optional[str] = None


class SubmitMatchResultOut(BaseModel):
    match: TournamentMatchOut
    tournament_completed: bool
    champion_participant_id: Optional[str] = None
    next_match: Optional[TournamentMatchOut] = None


def _raise_from_rpc_error(e: Exception):
    """As funções SQL levantam exceções no formato 'CODIGO: mensagem'.
    Mapeia isso para o HTTPException com status apropriado."""
    message = getattr(e, "message", None) or str(e)
    if "FORBIDDEN" in message:
        status_code = 403
    elif "NOT_FOUND" in message:
        status_code = 404
    elif any(code in message for code in (
        "INVALID_PLAYER_COUNT", "INVALID_TITLE", "INVALID_PARTICIPANTS",
        "INVALID_TEAMS", "INVALID_SCORE", "TOURNAMENT_NOT_IN_PROGRESS",
        "MATCH_NOT_READY", "INVALID_AMOUNT", "INVALID_DEADLINE",
        "INSUFFICIENT_BALANCE", "REGISTRATION_CLOSED", "ALREADY_JOINED",
        "TOURNAMENT_FULL", "NOT_PARTICIPANT", "INVALID_TOURNAMENT_TYPE",
        "INVALID_RESULT", "ALREADY_REPORTED", "LEAVE_WINDOW_CLOSED",
    )):
        status_code = 400
    else:
        status_code = 500

    detail = message.split(": ", 1)[1] if ": " in message else message
    raise HTTPException(status_code=status_code, detail=detail)


def _fetch_tournament_detail(tournament_id: str, host_id: str) -> dict:
    tournament_res = supabase.table("tournaments").select("*").eq("id", tournament_id).single().execute()
    tournament = tournament_res.data
    if not tournament:
        raise HTTPException(status_code=404, detail="Torneio não encontrado.")
    if tournament["host_id"] != host_id:
        raise HTTPException(status_code=403, detail="Você não tem acesso a este torneio.")

    participants_res = supabase.table("tournament_participants").select("*").eq(
        "tournament_id", tournament_id
    ).order("bracket_seed").execute()

    matches_res = supabase.table("tournament_matches").select("*").eq(
        "tournament_id", tournament_id
    ).order("round").order("slot").execute()

    return {
        **tournament,
        "participants": participants_res.data or [],
        "matches": matches_res.data or [],
    }


@router.post("/create", response_model=TournamentDetailOut)
def create_tournament(request: TournamentCreateRequest, user_id: str = Depends(get_current_user_id)):
    if request.max_players not in (4, 8, 16):
        raise HTTPException(status_code=400, detail="O torneio precisa ter 4, 8 ou 16 jogadores.")
    if len(request.participant_names) != request.max_players:
        raise HTTPException(status_code=400, detail="A quantidade de nomes não bate com o número de jogadores escolhido.")
    if any(not name.strip() for name in request.participant_names):
        raise HTTPException(status_code=400, detail="Nenhum nome de jogador pode ficar em branco.")
    if request.randomize_teams:
        if not request.team_names or len(request.team_names) != request.max_players:
            raise HTTPException(status_code=400, detail="A quantidade de times não bate com o número de jogadores.")
        if any(not team.strip() for team in request.team_names):
            raise HTTPException(status_code=400, detail="Nenhum nome de time pode ficar em branco.")

    try:
        result = supabase.rpc("fn_create_tournament", {
            "p_host_id": user_id,
            "p_title": request.title,
            "p_game": request.game,
            "p_max_players": request.max_players,
            "p_participant_names": request.participant_names,
            "p_randomize_teams": request.randomize_teams,
            "p_team_names": request.team_names or [],
        }).execute()
        tournament = result.data
    except HTTPException:
        raise
    except Exception as e:
        _raise_from_rpc_error(e)
        return  # inatingível — _raise_from_rpc_error sempre levanta

    return _fetch_tournament_detail(tournament["id"], user_id)


@router.post("/submit-result", response_model=SubmitMatchResultOut)
def submit_match_result(request: SubmitMatchResultRequest, user_id: str = Depends(get_current_user_id)):
    if request.score_a == request.score_b:
        raise HTTPException(status_code=400, detail="Não pode haver empate no mata-mata.")

    try:
        result = supabase.rpc("fn_submit_tournament_match_result", {
            "p_host_id": user_id,
            "p_tournament_id": request.tournament_id,
            "p_match_id": request.match_id,
            "p_score_a": request.score_a,
            "p_score_b": request.score_b,
        }).execute()
        return result.data
    except HTTPException:
        raise
    except Exception as e:
        _raise_from_rpc_error(e)


@router.get("/my-tournaments", response_model=List[TournamentSummaryOut])
def get_my_tournaments(user_id: str = Depends(get_current_user_id)):
    try:
        tournaments_res = supabase.table("tournaments").select(
            "id, title, game, max_players, status, champion_participant_id, created_at, completed_at"
        ).eq("host_id", user_id).eq("type", "local").order("created_at", desc=True).execute()
        return tournaments_res.data or []
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Erro ao carregar seus torneios: {str(e)}")


@router.get("/{tournament_id}", response_model=TournamentDetailOut)
def get_tournament(tournament_id: str, user_id: str = Depends(get_current_user_id)):
    return _fetch_tournament_detail(tournament_id, user_id)


# ═════════════════════════════════════════════════════════════════════════
# Torneio Online Pago (ver backend/07_online_tournaments.sql) — mesma tabela
# `tournaments`, filtrada por type='online_paid'. Diferente do Torneio Local:
# participantes são usuários reais que pagam a inscrição da própria
# carteira, a chave só é montada quando as vagas enchem, e o resultado de
# cada partida é reportado por consenso (win/loss dos dois lados), não
# digitado por um anfitrião confiável.
# ═════════════════════════════════════════════════════════════════════════

class OnlineTournamentCreateRequest(BaseModel):
    title: str
    game: str
    platform: str  # 'PS5', 'Xbox', 'PC', 'Crossplay'
    max_players: int  # 4, 8 ou 16
    entry_fee: float
    registration_deadline: datetime


class OnlineTournamentActionRequest(BaseModel):
    tournament_id: str


class SubmitOnlineMatchResultRequest(BaseModel):
    tournament_id: str
    match_id: str
    result: str  # 'win' ou 'loss'


class OnlineTournamentParticipantOut(BaseModel):
    id: str
    user_id: Optional[str] = None
    display_name: str
    bracket_seed: Optional[int] = None


class OnlineTournamentMatchOut(BaseModel):
    id: str
    round: int
    slot: int
    participant_a_id: Optional[str] = None
    participant_b_id: Optional[str] = None
    result_a: Optional[str] = None
    result_b: Optional[str] = None
    winner_participant_id: Optional[str] = None
    status: str
    is_third_place: bool = False


class OnlineTournamentRow(BaseModel):
    id: str
    host_id: str
    title: str
    game: str
    platform: Optional[str] = None
    max_players: int
    entry_fee: float
    prize_pool: float
    rake_amount: float
    status: str
    registration_deadline: Optional[str] = None
    champion_participant_id: Optional[str] = None
    runner_up_participant_id: Optional[str] = None
    third_place_participant_id: Optional[str] = None
    created_at: str
    completed_at: Optional[str] = None


class OnlineTournamentSummaryOut(OnlineTournamentRow):
    participant_count: int


class OnlineTournamentDetailOut(OnlineTournamentRow):
    participants: List[OnlineTournamentParticipantOut]
    matches: List[OnlineTournamentMatchOut]


class GenericActionOut(BaseModel):
    status: str
    message: str


class OnlineMatchResultOut(BaseModel):
    status: str
    message: Optional[str] = None
    tournament_completed: Optional[bool] = None
    champion_participant_id: Optional[str] = None
    match: Optional[OnlineTournamentMatchOut] = None
    next_match: Optional[OnlineTournamentMatchOut] = None


def _attach_participant_counts(tournaments: list) -> list:
    if not tournaments:
        return []
    ids = [t["id"] for t in tournaments]
    participants_res = supabase.table("tournament_participants").select("tournament_id").in_("tournament_id", ids).execute()
    counts: dict = {}
    for p in (participants_res.data or []):
        counts[p["tournament_id"]] = counts.get(p["tournament_id"], 0) + 1
    return [{**t, "participant_count": counts.get(t["id"], 0)} for t in tournaments]


def _fetch_online_tournament_detail(tournament_id: str) -> dict:
    tournament_res = supabase.table("tournaments").select("*").eq("id", tournament_id).eq("type", "online_paid").execute()
    tournament = tournament_res.data[0] if tournament_res.data else None
    if not tournament:
        raise HTTPException(status_code=404, detail="Torneio não encontrado.")

    participants_res = supabase.table("tournament_participants").select(
        "id, user_id, display_name, bracket_seed"
    ).eq("tournament_id", tournament_id).order("created_at").execute()

    matches_res = supabase.table("tournament_matches").select(
        "id, round, slot, participant_a_id, participant_b_id, result_a, result_b, winner_participant_id, status, is_third_place"
    ).eq("tournament_id", tournament_id).order("round").order("slot").execute()

    return {
        **tournament,
        "participants": participants_res.data or [],
        "matches": matches_res.data or [],
    }


@router.post("/online/create", response_model=OnlineTournamentDetailOut)
def create_online_tournament(request: OnlineTournamentCreateRequest, user_id: str = Depends(get_current_user_id)):
    if request.max_players not in (4, 8, 16):
        raise HTTPException(status_code=400, detail="O torneio precisa ter 4, 8 ou 16 jogadores.")
    if request.entry_fee <= 0:
        raise HTTPException(status_code=400, detail="A taxa de inscrição precisa ser maior que zero.")

    try:
        result = supabase.rpc("fn_create_online_tournament", {
            "p_host_id": user_id,
            "p_title": request.title,
            "p_game": request.game,
            "p_platform": request.platform,
            "p_max_players": request.max_players,
            "p_entry_fee": request.entry_fee,
            "p_registration_deadline": request.registration_deadline.isoformat(),
        }).execute()
        tournament = result.data
    except HTTPException:
        raise
    except Exception as e:
        _raise_from_rpc_error(e)
        return  # inatingível — _raise_from_rpc_error sempre levanta

    return _fetch_online_tournament_detail(tournament["id"])


@router.get("/online/open", response_model=List[OnlineTournamentSummaryOut])
def get_open_online_tournaments():
    # Rota pública de propósito: vitrine de torneios online (inscrição aberta,
    # em andamento ou concluídos) visível até pra visitante deslogado — mesmo
    # padrão de /api/challenges/open.
    try:
        supabase.rpc("fn_expire_stale_online_tournaments", {}).execute()

        tournaments_res = supabase.table("tournaments").select("*").eq(
            "type", "online_paid"
        ).in_("status", ["registration_open", "in_progress", "completed"]).order(
            "created_at", desc=True
        ).execute()
        return _attach_participant_counts(tournaments_res.data or [])
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Erro ao buscar torneios online: {str(e)}")


@router.get("/online/my", response_model=List[OnlineTournamentSummaryOut])
def get_my_online_tournaments(user_id: str = Depends(get_current_user_id)):
    try:
        participant_rows = supabase.table("tournament_participants").select(
            "tournament_id"
        ).eq("user_id", user_id).execute()
        tournament_ids = list({p["tournament_id"] for p in (participant_rows.data or [])})
        if not tournament_ids:
            return []

        tournaments_res = supabase.table("tournaments").select("*").eq(
            "type", "online_paid"
        ).in_("id", tournament_ids).order("created_at", desc=True).execute()
        return _attach_participant_counts(tournaments_res.data or [])
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Erro ao carregar seus torneios online: {str(e)}")


@router.post("/online/join", response_model=OnlineTournamentDetailOut)
def join_online_tournament(request: OnlineTournamentActionRequest, user_id: str = Depends(get_current_user_id)):
    try:
        supabase.rpc("fn_join_online_tournament", {
            "p_tournament_id": request.tournament_id,
            "p_user_id": user_id,
        }).execute()
    except HTTPException:
        raise
    except Exception as e:
        _raise_from_rpc_error(e)
        return

    return _fetch_online_tournament_detail(request.tournament_id)


@router.post("/online/leave", response_model=GenericActionOut)
def leave_online_tournament(request: OnlineTournamentActionRequest, user_id: str = Depends(get_current_user_id)):
    try:
        result = supabase.rpc("fn_leave_online_tournament", {
            "p_tournament_id": request.tournament_id,
            "p_user_id": user_id,
        }).execute()
        return result.data
    except HTTPException:
        raise
    except Exception as e:
        _raise_from_rpc_error(e)


@router.post("/online/submit-result", response_model=OnlineMatchResultOut)
def submit_online_match_result(request: SubmitOnlineMatchResultRequest, user_id: str = Depends(get_current_user_id)):
    if request.result not in ("win", "loss"):
        raise HTTPException(status_code=400, detail="Resultado inválido. Deve ser 'win' ou 'loss'.")

    try:
        result = supabase.rpc("fn_submit_online_match_result", {
            "p_tournament_id": request.tournament_id,
            "p_match_id": request.match_id,
            "p_user_id": user_id,
            "p_result": request.result,
        }).execute()
        return result.data
    except HTTPException:
        raise
    except Exception as e:
        _raise_from_rpc_error(e)


@router.get("/online/{tournament_id}", response_model=OnlineTournamentDetailOut)
def get_online_tournament(tournament_id: str):
    # Pública de propósito (mesmo motivo de /online/open) — mas ainda faz a
    # varredura de expiração antes de responder, pra quem cair direto na
    # tela de detalhe de um torneio já vencido não ver um estado incoerente.
    try:
        supabase.rpc("fn_expire_stale_online_tournaments", {}).execute()
    except Exception:
        pass
    return _fetch_online_tournament_detail(tournament_id)
