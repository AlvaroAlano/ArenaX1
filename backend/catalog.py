"""Catálogo fechado de valores aceitos pelo backend (plataformas e jogos).

Fonte única de verdade server-side: espelha `frontend/src/constants/games.ts`
e as opções de plataforma dos formulários. Sem isso, a API aceitava qualquer
string em `platform`/`game` (ACHADO-08 do teste geral) — o que não abre
injeção (as chamadas são RPC parametrizadas), mas quebra filtro, ranking e
estatística que assumem esse conjunto fechado. Validar aqui fecha a porta.
"""

ALLOWED_PLATFORMS = {"PS5", "Xbox", "PC", "Crossplay"}
ALLOWED_GAMES = {"EA FC 25", "EA FC 26", "eFootball"}


def validate_platform_and_game(platform: str, game: str) -> None:
    """Levanta ValueError se plataforma/jogo não estiverem no catálogo.
    O chamador converte em HTTPException 400 com a mensagem amigável."""
    if platform not in ALLOWED_PLATFORMS:
        raise ValueError(
            f"Plataforma inválida. Escolha uma de: {', '.join(sorted(ALLOWED_PLATFORMS))}."
        )
    if game not in ALLOWED_GAMES:
        raise ValueError(
            f"Jogo inválido. Escolha um de: {', '.join(sorted(ALLOWED_GAMES))}."
        )
