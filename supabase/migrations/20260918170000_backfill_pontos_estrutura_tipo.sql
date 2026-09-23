-- PENDENTE — para revisão da equipe antes de aplicar.
--
-- Completa `estrutura_id` e `tipo_ensaio_id` em `pontos_ensaios_geral` nas
-- linhas antigas que ficaram sem eles (criadas por versões anteriores do
-- app, que não gravavam a estrutura). O app atual já grava os dois no INSERT
-- e o trigger `private.set_point_actor_company` recusa ponto novo sem eles;
-- este script só conserta o passado. Não sobrescreve nada: só preenche nulos.
--
-- Pode rodar mais de uma vez.

begin;

-- 1) Estrutura a partir do elemento do ponto. Só quando a estrutura está
--    vinculada ao projeto do ponto (projeto_estruturas): o trigger
--    set_point_actor_company recusa estrutura fora do projeto e, sem este
--    filtro, UMA linha inconsistente abortaria a atualização inteira.
update public.pontos_ensaios_geral p
set estrutura_id = e.estrutura_id
from public.elementos_estruturais e
where p.estrutura_id is null
  and p.elemento_estrutural_id = e.id
  and e.estrutura_id is not null
  and exists (
    select 1
    from public.projeto_estruturas pe
    where pe.projeto_id = p.projeto_id
      and pe.estrutura_id = e.estrutura_id
  );

-- 2) Tipo de ensaio a partir do texto `tipo_ensaio` (nome gravado junto).
--    Só quando o nome casa com UM único tipo (sem diferenciar maiúsculas).
update public.pontos_ensaios_geral p
set tipo_ensaio_id = t.id
from public.tipos_ensaio t
where p.tipo_ensaio_id is null
  and lower(trim(t.nome)) = lower(trim(p.tipo_ensaio))
  and (
    select count(*) from public.tipos_ensaio t2
    where lower(trim(t2.nome)) = lower(trim(p.tipo_ensaio))
  ) = 1;

-- 2b) Nomes antigos que não batem exatamente com tipos_ensaio.nome.
update public.pontos_ensaios_geral p
set tipo_ensaio_id = t.id
from public.tipos_ensaio t
where p.tipo_ensaio_id is null
  and lower(p.tipo_ensaio) like '%carbonata%'
  and lower(t.nome) like '%carbonata%';

commit;

-- Depois de aplicar, o que ainda sobrar sem estrutura/tipo precisa de
-- olhar manual (elemento apagado, estrutura fora do projeto, nome de ensaio
-- desconhecido):
--
--   select id, criado_em, projeto_id, elemento_estrutural_id, tipo_ensaio,
--          estrutura_id is null as sem_estrutura,
--          tipo_ensaio_id is null as sem_tipo
--   from public.pontos_ensaios_geral
--   where estrutura_id is null or tipo_ensaio_id is null
--   order by criado_em;
--
-- Com tudo preenchido, vale travar de vez (o trigger só vale no INSERT):
--
--   alter table public.pontos_ensaios_geral alter column estrutura_id set not null;
--   alter table public.pontos_ensaios_geral alter column tipo_ensaio_id set not null;
