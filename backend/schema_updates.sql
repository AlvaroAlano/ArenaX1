-- Execute este script no SQL Editor do seu painel Supabase

ALTER TABLE public.challenges 
ADD COLUMN IF NOT EXISTS creator_result TEXT DEFAULT NULL,
ADD COLUMN IF NOT EXISTS opponent_result TEXT DEFAULT NULL,
ADD COLUMN IF NOT EXISTS winner_id UUID REFERENCES auth.users(id) DEFAULT NULL;
