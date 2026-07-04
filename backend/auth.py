import os
from fastapi import Header, HTTPException
from supabase import create_client, Client
from dotenv import load_dotenv

load_dotenv()

supabase_url = os.getenv("SUPABASE_URL")
supabase_anon_key = os.getenv("SUPABASE_KEY")
supabase_service_key = os.getenv("SUPABASE_SERVICE_ROLE_KEY")

if not supabase_url or not supabase_anon_key:
    raise ValueError("Variáveis de ambiente do Supabase não configuradas no Backend.")

# Cliente com a chave anônima: usado só para validar o token do usuário,
# nunca para ler/escrever dados (isso é papel do client service_role).
_auth_client: Client = create_client(supabase_url, supabase_anon_key)

# Cliente service_role só pra conferir profiles.is_admin (ignora RLS de propósito
# — sem isso, um usuário não-admin poderia nunca ter essa checagem confirmada
# com segurança via client anônimo).
_admin_check_client: Client = create_client(supabase_url, supabase_service_key) if supabase_service_key else None


def get_current_user_id(authorization: str = Header(default=None)) -> str:
    """Valida o JWT do Supabase enviado pelo Frontend e retorna o user_id real.

    Nunca confiar em um user_id/creator_id vindo do corpo da requisição:
    ele precisa vir sempre do token verificado aqui.
    """
    if not authorization or not authorization.lower().startswith("bearer "):
        raise HTTPException(status_code=401, detail="Token de autenticação ausente.")

    token = authorization.split(" ", 1)[1].strip()
    if not token:
        raise HTTPException(status_code=401, detail="Token de autenticação ausente.")

    try:
        user_res = _auth_client.auth.get_user(token)
    except Exception:
        raise HTTPException(status_code=401, detail="Token de autenticação inválido ou expirado.")

    if not user_res or not user_res.user:
        raise HTTPException(status_code=401, detail="Token de autenticação inválido ou expirado.")

    return user_res.user.id


def get_current_admin_user_id(authorization: str = Header(default=None)) -> str:
    """Mesma validação de get_current_user_id, mas também exige profiles.is_admin = true.

    Usado pelas rotas de /api/admin/* — portal de admin é conta real
    (login normal) com essa flag no perfil, não uma senha solta.
    """
    user_id = get_current_user_id(authorization)

    if not _admin_check_client:
        raise HTTPException(status_code=500, detail="Verificação de administrador não configurada no backend.")

    profile_res = _admin_check_client.table("profiles").select("is_admin").eq("id", user_id).execute()
    profile = profile_res.data[0] if profile_res.data else None
    if not profile or not profile.get("is_admin"):
        raise HTTPException(status_code=403, detail="Acesso restrito a administradores.")

    return user_id
