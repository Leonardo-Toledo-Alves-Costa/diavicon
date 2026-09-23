-- PENDENTE: para a equipe revisar e aplicar. Ainda NÃO está no Supabase.
--
-- Limite de convites de colaborador por empresa (anti-spam).
--
-- A função convidar-funcionario grava cada convite na auditoria
-- (private.auditoria, ação 'convite.enviado') e, antes de criar um novo,
-- pergunta quantos a empresa enviou nas últimas 24 h. Acima de 20, recusa.
-- Contar pela auditoria impede o ciclo "convidar → desfazer → convidar"
-- (o convite desfeito some de usuarios, mas não da auditoria).
--
-- Sem esta função no banco, a edge function continua convidando normalmente
-- (só não limita). Pré-requisito: 20260921130000_lgpd_privacidade.sql
-- (aplicada), que criou private.auditoria.
--
-- Pode rodar mais de uma vez sem erro.

begin;

create index if not exists auditoria_convites_idx
  on private.auditoria (empresa_id, ocorrido_em)
  where acao = 'convite.enviado';

create or replace function public.convites_empresa_ultimas_24h(p_empresa_id uuid)
returns integer
language sql
stable
security definer
set search_path = public, pg_catalog
as $$
  select count(*)::integer
  from private.auditoria a
  where a.acao = 'convite.enviado'
    and a.empresa_id = p_empresa_id
    and a.ocorrido_em > now() - interval '24 hours'
$$;

-- Só a edge function (service role) chama.
revoke all on function public.convites_empresa_ultimas_24h(uuid) from public, anon, authenticated;
grant execute on function public.convites_empresa_ultimas_24h(uuid) to service_role;

commit;
