import { supabase } from './supabase'

const API_URL = import.meta.env.VITE_API_URL || 'http://localhost:8000'

class ApiError extends Error {}

async function authHeaders(): Promise<Record<string, string>> {
  const { data } = await supabase.auth.getSession()
  const token = data.session?.access_token
  return token ? { Authorization: `Bearer ${token}` } : {}
}

async function request<T>(path: string, options: RequestInit = {}): Promise<T> {
  let res: Response
  try {
    res = await fetch(`${API_URL}${path}`, {
      ...options,
      headers: {
        'Content-Type': 'application/json',
        ...(await authHeaders()),
        ...(options.headers as Record<string, string> | undefined),
      },
    })
  } catch {
    // fetch rejeita com um TypeError genérico do navegador (ex: "Failed to
    // fetch") quando o servidor está fora do ar — nunca mostrar isso cru.
    throw new ApiError('Não foi possível conectar ao servidor. Verifique sua conexão ou tente novamente em instantes.')
  }

  const isJson = res.headers.get('content-type')?.includes('application/json')
  const body = isJson ? await res.json().catch(() => null) : null

  if (!res.ok) {
    throw new ApiError(body?.detail || 'Erro ao comunicar com o servidor.')
  }

  return body as T
}

export const api = {
  get: <T>(path: string) => request<T>(path, { method: 'GET' }),
  post: <T>(path: string, body?: unknown) =>
    request<T>(path, { method: 'POST', body: body !== undefined ? JSON.stringify(body) : undefined }),
}
