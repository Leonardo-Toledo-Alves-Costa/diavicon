-- One read-only result set so PGlite/PostgREST callers can prepare it.
select 'regiao_sem_projeto'::text as tipo_problema, 'regioes_ensaio'::text as tabela,
  r.id, jsonb_build_object('planta_id', r.planta_id, 'empresa_id', r.empresa_id,
    'projetos_candidatos', array_agg(distinct pe.projeto_id) filter (where pe.projeto_id is not null)) as detalhes
from public.regioes_ensaio r
left join public.estruturas_plantas ep on ep.id = r.planta_id
left join public.projeto_estruturas pe on pe.estrutura_id = ep.estrutura_id
where r.projeto_id is null
group by r.id, r.planta_id, r.empresa_id
union all
select case when p.estrutura_id is null then 'ponto_sem_estrutura'
            when p.tipo_ensaio_id is null then 'ponto_sem_tipo_ensaio'
            when p.elemento_estrutural_id is null then 'ponto_sem_elemento'
            else 'ponto_estrutura_diverge_elemento' end,
  'pontos_ensaios_geral', p.id,
  jsonb_build_object('projeto_id', p.projeto_id, 'estrutura_id', p.estrutura_id,
    'elemento_estrutural_id', p.elemento_estrutural_id, 'tipo_ensaio_id', p.tipo_ensaio_id)
from public.pontos_ensaios_geral p
where p.estrutura_id is null or p.tipo_ensaio_id is null or p.elemento_estrutural_id is null
   or (p.estrutura_id is not null and p.elemento_estrutural_id is not null and not exists (
     select 1 from public.elementos_estruturais e where e.id = p.elemento_estrutural_id and e.estrutura_id = p.estrutura_id))
union all
select 'empresa_autora_nao_resolvida', 'pontos_ensaios_geral', id, jsonb_build_object('criado_por', criado_por)
from public.pontos_ensaios_geral where empresa_autora_id is null
union all
select 'empresa_autora_nao_resolvida', 'relatorio_ensaio', id, jsonb_build_object('criado_por', criado_por)
from public.relatorio_ensaio where empresa_autora_id is null
