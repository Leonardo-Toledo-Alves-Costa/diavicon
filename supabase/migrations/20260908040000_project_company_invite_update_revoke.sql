-- Prevent direct client-side invite status transitions outside the transactional RPC.
revoke update on table public.projeto_empresas_colaboradoras
from authenticated;

revoke update (status) on table public.projeto_empresas_colaboradoras
from authenticated;
