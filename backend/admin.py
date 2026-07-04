import os
from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel
from supabase import create_client, Client
from dotenv import load_dotenv

from auth import get_current_admin_user_id

load_dotenv()

supabase_url = os.getenv("SUPABASE_URL")
supabase_service_key = os.getenv("SUPABASE_SERVICE_ROLE_KEY")

if not supabase_url or not supabase_service_key:
    raise ValueError("Variáveis de ambiente do Supabase não configuradas no Backend.")

supabase: Client = create_client(supabase_url, supabase_service_key)

router = APIRouter(prefix="/api/admin", tags=["Administração"])


class ResolveDisputeRequest(BaseModel):
    match_id: str
    winner_participant_id: str


def _raise_from_rpc_error(e: Exception):
    message = getattr(e, "message", None) or str(e)
    if "NOT_FOUND" in message:
        status_code = 404
    elif any(code in message for code in ("MATCH_NOT_DISPUTED", "INVALID_WINNER", "TOURNAMENT_NOT_IN_PROGRESS")):
        status_code = 400
    else:
        status_code = 500
    detail = message.split(": ", 1)[1] if ": " in message else message
    raise HTTPException(status_code=status_code, detail=detail)


@router.get("/metrics")
def get_dashboard_metrics(admin_user_id: str = Depends(get_current_admin_user_id)):
    try:
        result = supabase.rpc("fn_admin_dashboard_metrics", {}).execute()
        return result.data
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Erro ao calcular métricas: {str(e)}")


@router.get("/disputes")
def get_open_tournament_disputes(admin_user_id: str = Depends(get_current_admin_user_id)):
    # Junta os dados espalhados em 4 tabelas (disputes/matches/tournaments/
    # participants) pra dar pro admin o suficiente pra decidir sem precisar
    # abrir o painel do Supabase: quem jogou contra quem, em qual torneio.
    try:
        disputes_res = supabase.table("disputes").select(
            "id, tournament_match_id, created_at"
        ).eq("status", "open").not_.is_("tournament_match_id", "null").order("created_at", desc=True).execute()
        disputes = disputes_res.data or []
        if not disputes:
            return []

        match_ids = [d["tournament_match_id"] for d in disputes]
        matches_res = supabase.table("tournament_matches").select(
            "id, tournament_id, round, participant_a_id, participant_b_id"
        ).in_("id", match_ids).execute()
        matches_by_id = {m["id"]: m for m in (matches_res.data or [])}

        tournament_ids = list({m["tournament_id"] for m in matches_by_id.values()})
        tournaments_res = supabase.table("tournaments").select("id, title").in_("id", tournament_ids).execute()
        tournaments_by_id = {t["id"]: t for t in (tournaments_res.data or [])}

        participant_ids = set()
        for m in matches_by_id.values():
            if m.get("participant_a_id"):
                participant_ids.add(m["participant_a_id"])
            if m.get("participant_b_id"):
                participant_ids.add(m["participant_b_id"])
        participants_res = supabase.table("tournament_participants").select(
            "id, display_name, user_id"
        ).in_("id", list(participant_ids)).execute()
        participants_by_id = {p["id"]: p for p in (participants_res.data or [])}

        result = []
        for d in disputes:
            match = matches_by_id.get(d["tournament_match_id"])
            if not match:
                continue
            tournament = tournaments_by_id.get(match["tournament_id"], {})
            result.append({
                "dispute_id": d["id"],
                "match_id": match["id"],
                "tournament_id": match["tournament_id"],
                "tournament_title": tournament.get("title", "?"),
                "round": match["round"],
                "participant_a": participants_by_id.get(match.get("participant_a_id")),
                "participant_b": participants_by_id.get(match.get("participant_b_id")),
                "created_at": d["created_at"],
            })
        return result
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Erro ao carregar disputas: {str(e)}")


@router.post("/tournaments/resolve-dispute")
def resolve_tournament_dispute(request: ResolveDisputeRequest, admin_user_id: str = Depends(get_current_admin_user_id)):
    try:
        result = supabase.rpc("fn_resolve_online_match_dispute", {
            "p_match_id": request.match_id,
            "p_winner_participant_id": request.winner_participant_id,
            "p_admin_user_id": admin_user_id,
        }).execute()
        return result.data
    except HTTPException:
        raise
    except Exception as e:
        _raise_from_rpc_error(e)
