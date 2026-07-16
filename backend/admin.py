import os
from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel, Field
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


class SetTicketStatusRequest(BaseModel):
    status: str


class RejectWithdrawRequest(BaseModel):
    # Motivo obrigatório: vira a notificação que o usuário recebe ("Motivo: ...")
    # e o rastro de auditoria da recusa (ACHADO-07). Sem isso, o usuário era
    # avisado da rejeição sem nenhuma explicação.
    reason: str = Field(min_length=3, max_length=500)


class ResolveChallengeDisputeRequest(BaseModel):
    winner_id: str


class CancelChallengeDisputeRequest(BaseModel):
    reason: str = Field(min_length=3, max_length=500)


def _raise_from_rpc_error(e: Exception):
    message = getattr(e, "message", None) or str(e)
    if "NOT_FOUND" in message:
        status_code = 404
    elif "NOT_ALLOWED" in message:
        status_code = 403
    elif any(code in message for code in (
        "MATCH_NOT_DISPUTED", "CHALLENGE_NOT_DISPUTED", "INVALID_WINNER",
        "TOURNAMENT_NOT_IN_PROGRESS", "INVALID_STATUS", "REASON_REQUIRED",
    )):
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


@router.get("/support/tickets")
def list_support_tickets(status: str = "open", admin_user_id: str = Depends(get_current_admin_user_id)):
    """Fila de tickets de suporte pro admin. status='open' (padrão), 'resolved',
    'closed' ou 'all'. Traz o perfil de quem abriu pra decidir sem sair da tela."""
    try:
        query = supabase.table("support_tickets").select(
            "*, user_profile:user_id(username, fair_play_rating)"
        ).order("updated_at", desc=True)
        if status in ("open", "resolved", "closed"):
            query = query.eq("status", status)
        res = query.execute()
        return res.data or []
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Erro ao carregar tickets: {str(e)}")


@router.post("/support/tickets/{ticket_id}/status")
def set_support_ticket_status(ticket_id: str, request: SetTicketStatusRequest, admin_user_id: str = Depends(get_current_admin_user_id)):
    try:
        result = supabase.rpc("fn_set_support_ticket_status", {
            "p_ticket_id": ticket_id,
            "p_admin_id": admin_user_id,
            "p_status": request.status,
        }).execute()
        return result.data
    except HTTPException:
        raise
    except Exception as e:
        _raise_from_rpc_error(e)


@router.get("/withdrawals")
def list_withdrawals(status: str = "pending", admin_user_id: str = Depends(get_current_admin_user_id)):
    """Fila de saques pro admin processar manualmente (o Mercado Pago não manda
    Pix pra chave de terceiro via API — ver pix.py). Junta transactions ->
    wallets -> profiles na mão, mesmo estilo do GET /disputes acima."""
    try:
        tx_query = supabase.table("transactions").select(
            "id, amount, pix_key, status, description, created_at, processed_at, failure_reason, wallet_id"
        ).eq("type", "withdraw").order("created_at", desc=True)
        if status in ("pending", "completed", "failed"):
            tx_query = tx_query.eq("status", status)
        transactions = tx_query.execute().data or []
        if not transactions:
            return []

        wallet_ids = list({t["wallet_id"] for t in transactions})
        wallets_res = supabase.table("wallets").select("id, user_id").in_("id", wallet_ids).execute()
        user_id_by_wallet = {w["id"]: w["user_id"] for w in (wallets_res.data or [])}

        profile_ids = list(set(user_id_by_wallet.values()))
        profiles_res = supabase.table("profiles").select("id, username").in_("id", profile_ids).execute()
        username_by_profile = {p["id"]: p["username"] for p in (profiles_res.data or [])}

        result = []
        for t in transactions:
            profile_id = user_id_by_wallet.get(t["wallet_id"])
            result.append({
                "id": t["id"],
                "amount": abs(float(t["amount"])),
                "pix_key": t["pix_key"],
                "status": t["status"],
                "description": t["description"],
                "created_at": t["created_at"],
                "processed_at": t["processed_at"],
                "failure_reason": t["failure_reason"],
                "username": username_by_profile.get(profile_id, "?"),
            })
        return result
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Erro ao carregar saques: {str(e)}")


@router.post("/withdrawals/{transaction_id}/confirm")
def confirm_withdrawal(transaction_id: str, admin_user_id: str = Depends(get_current_admin_user_id)):
    try:
        result = supabase.rpc("fn_confirm_withdraw", {
            "p_transaction_id": transaction_id,
            "p_admin_id": admin_user_id,
        }).execute()
        return result.data
    except HTTPException:
        raise
    except Exception as e:
        _raise_from_rpc_error(e)


@router.get("/challenge-disputes")
def list_challenge_disputes(status: str = "open", admin_user_id: str = Depends(get_current_admin_user_id)):
    """Disputas de desafio 1v1 (challenge_id) — separado de GET /disputes, que
    só cobre disputas de torneio online (tournament_match_id). Junta
    disputes -> challenges -> profiles -> primeira mensagem (motivo) na mão,
    mesmo estilo do resto deste arquivo."""
    try:
        disputes_res = supabase.table("disputes").select(
            "id, challenge_id, status, resolution, created_at"
        ).eq("status", status).not_.is_("challenge_id", "null").order("created_at", desc=True).execute()
        disputes = disputes_res.data or []
        if not disputes:
            return []

        challenge_ids = [d["challenge_id"] for d in disputes]
        challenges_res = supabase.table("challenges").select(
            "id, game, platform, bet_amount, creator_id, opponent_id, creator_result, opponent_result"
        ).in_("id", challenge_ids).execute()
        challenges_by_id = {c["id"]: c for c in (challenges_res.data or [])}

        profile_ids = set()
        for c in challenges_by_id.values():
            if c.get("creator_id"):
                profile_ids.add(c["creator_id"])
            if c.get("opponent_id"):
                profile_ids.add(c["opponent_id"])
        profiles_res = supabase.table("profiles").select("id, username").in_("id", list(profile_ids)).execute()
        profiles_by_id = {p["id"]: p for p in (profiles_res.data or [])}

        dispute_ids = [d["id"] for d in disputes]
        messages_res = supabase.table("dispute_messages").select(
            "dispute_id, message, created_at"
        ).in_("dispute_id", dispute_ids).order("created_at").execute()
        first_message_by_dispute = {}
        for m in (messages_res.data or []):
            first_message_by_dispute.setdefault(m["dispute_id"], m["message"])

        result = []
        for d in disputes:
            challenge = challenges_by_id.get(d["challenge_id"])
            if not challenge:
                continue
            result.append({
                "dispute_id": d["id"],
                "challenge_id": d["challenge_id"],
                "status": d["status"],
                "resolution": d["resolution"],
                "created_at": d["created_at"],
                "game": challenge["game"],
                "platform": challenge["platform"],
                "bet_amount": challenge["bet_amount"],
                "creator": {"id": challenge["creator_id"], **(profiles_by_id.get(challenge["creator_id"], {}))},
                "opponent": {"id": challenge["opponent_id"], **(profiles_by_id.get(challenge["opponent_id"], {}))} if challenge.get("opponent_id") else None,
                "creator_result": challenge["creator_result"],
                "opponent_result": challenge["opponent_result"],
                "reason": first_message_by_dispute.get(d["id"]),
            })
        return result
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Erro ao carregar disputas de desafio: {str(e)}")


@router.get("/challenge-disputes/{challenge_id}")
def get_challenge_dispute_detail(challenge_id: str, admin_user_id: str = Depends(get_current_admin_user_id)):
    """Tudo que o admin precisa pra analisar UMA disputa de desafio 1v1 numa
    tela só: dados do desafio, perfis dos dois, linha do tempo (criação →
    solicitação → aceite → disputa), o chat entre os jogadores (challenge_
    messages) e o chat de mediação com os prints (dispute_messages). Como o
    admin não é participante, a RLS bloquearia esses chats via cliente normal
    — por isso é o backend (service_role) que lê e entrega tudo pronto."""
    try:
        challenge_res = supabase.table("challenges").select("*").eq("id", challenge_id).execute()
        challenge = (challenge_res.data or [None])[0]
        if not challenge:
            raise HTTPException(status_code=404, detail="Desafio não encontrado.")

        dispute_res = supabase.table("disputes").select(
            "id, status, resolution, created_at, updated_at"
        ).eq("challenge_id", challenge_id).execute()
        dispute = (dispute_res.data or [None])[0]

        # Perfis de todo mundo que aparece na tela (dois jogadores + quem mandou
        # mensagem em qualquer um dos chats + quem solicitou entrada).
        join_res = supabase.table("challenge_join_requests").select(
            "id, requester_id, status, created_at, updated_at"
        ).eq("challenge_id", challenge_id).order("created_at").execute()
        join_requests = join_res.data or []

        match_msgs_res = supabase.table("challenge_messages").select(
            "id, sender_id, message, created_at"
        ).eq("challenge_id", challenge_id).order("created_at").execute()
        match_messages = match_msgs_res.data or []

        dispute_messages = []
        if dispute:
            dm_res = supabase.table("dispute_messages").select(
                "id, sender_id, message, attachment_url, created_at"
            ).eq("dispute_id", dispute["id"]).order("created_at").execute()
            dispute_messages = dm_res.data or []

        profile_ids = set()
        for pid in (challenge.get("creator_id"), challenge.get("opponent_id")):
            if pid:
                profile_ids.add(pid)
        for r in join_requests:
            profile_ids.add(r["requester_id"])
        for m in match_messages:
            profile_ids.add(m["sender_id"])
        for m in dispute_messages:
            profile_ids.add(m["sender_id"])
        profiles_res = supabase.table("profiles").select(
            "id, username, fair_play_rating"
        ).in_("id", list(profile_ids)).execute()
        profiles_by_id = {p["id"]: p for p in (profiles_res.data or [])}

        def profile(pid):
            if not pid:
                return None
            p = profiles_by_id.get(pid, {})
            return {"id": pid, "username": p.get("username"), "fair_play_rating": p.get("fair_play_rating")}

        creator = profile(challenge.get("creator_id"))
        opponent = profile(challenge.get("opponent_id"))

        # Linha do tempo montada só com o que temos timestamp confiável (não
        # inventa horário de reporte que o schema não guarda). Cada evento:
        # {key, label, at, actor}. Ordenada no fim por horário.
        timeline = [{
            "key": "created",
            "label": "Desafio criado",
            "at": challenge["created_at"],
            "actor": creator["username"] if creator else None,
        }]
        accepted_req = next((r for r in join_requests if r["status"] == "accepted"), None)
        if accepted_req:
            requester = profile(accepted_req["requester_id"])
            timeline.append({
                "key": "requested",
                "label": "Oponente solicitou entrada",
                "at": accepted_req["created_at"],
                "actor": requester["username"] if requester else None,
            })
            timeline.append({
                "key": "accepted",
                "label": "Criador aceitou o oponente",
                "at": accepted_req["updated_at"],
                "actor": creator["username"] if creator else None,
            })
        if dispute:
            timeline.append({
                "key": "disputed",
                "label": "Disputa aberta",
                "at": dispute["created_at"],
                "actor": None,
            })
        timeline.sort(key=lambda e: e["at"])

        def with_sender(m):
            sp = profiles_by_id.get(m["sender_id"], {})
            return {**m, "sender_username": sp.get("username", "?")}

        return {
            "challenge": {
                "id": challenge["id"],
                "game": challenge["game"],
                "platform": challenge["platform"],
                "bet_amount": challenge["bet_amount"],
                "status": challenge["status"],
                "creator_result": challenge.get("creator_result"),
                "opponent_result": challenge.get("opponent_result"),
                "created_at": challenge["created_at"],
                "updated_at": challenge["updated_at"],
            },
            "creator": creator,
            "opponent": opponent,
            "dispute": dispute,
            "timeline": timeline,
            "match_messages": [with_sender(m) for m in match_messages],
            "dispute_messages": [with_sender(m) for m in dispute_messages],
        }
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Erro ao carregar a disputa: {str(e)}")


@router.post("/challenge-disputes/{challenge_id}/resolve")
def resolve_challenge_dispute(challenge_id: str, request: ResolveChallengeDisputeRequest, admin_user_id: str = Depends(get_current_admin_user_id)):
    try:
        result = supabase.rpc("fn_resolve_challenge_dispute", {
            "p_challenge_id": challenge_id,
            "p_winner_id": request.winner_id,
        }).execute()
        return result.data
    except HTTPException:
        raise
    except Exception as e:
        _raise_from_rpc_error(e)


@router.post("/challenge-disputes/{challenge_id}/cancel")
def cancel_challenge_dispute(challenge_id: str, request: CancelChallengeDisputeRequest, admin_user_id: str = Depends(get_current_admin_user_id)):
    try:
        result = supabase.rpc("fn_cancel_challenge_dispute", {
            "p_challenge_id": challenge_id,
            "p_admin_id": admin_user_id,
            "p_reason": request.reason,
        }).execute()
        return result.data
    except HTTPException:
        raise
    except Exception as e:
        _raise_from_rpc_error(e)


@router.post("/withdrawals/{transaction_id}/reject")
def reject_withdrawal(transaction_id: str, request: RejectWithdrawRequest, admin_user_id: str = Depends(get_current_admin_user_id)):
    reason = request.reason.strip()
    if len(reason) < 3:
        raise HTTPException(status_code=400, detail="Descreva o motivo da rejeição do saque.")
    try:
        result = supabase.rpc("fn_reject_withdraw", {
            "p_transaction_id": transaction_id,
            "p_admin_id": admin_user_id,
            "p_reason": reason,
        }).execute()
        return result.data
    except HTTPException:
        raise
    except Exception as e:
        _raise_from_rpc_error(e)
