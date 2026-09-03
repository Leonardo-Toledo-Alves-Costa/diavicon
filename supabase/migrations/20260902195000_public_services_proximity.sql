-- Keep service/product discovery ordered by the same locality buckets as the
-- company feed while retaining a deterministic tie-breaker for pagination.
create or replace function public.list_public_company_services(
  p_empresa_id uuid default null,
  p_search text default null,
  p_categoria text default null,
  p_limit integer default 50,
  p_offset integer default 0
)
returns table (
  servico_id uuid,
  empresa_id uuid,
  nome text,
  objetivo text,
  foto_principal text,
  categoria text,
  link_anexo text,
  nome_anexo text,
  descricao text,
  empresa_nome text,
  empresa_foto_url text,
  cidade text,
  estado text
)
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare
  v_actor_id uuid := (select auth.uid());
  v_cidade text;
  v_estado text;
  v_limit integer := least(greatest(coalesce(p_limit, 50), 1), 100);
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
  v_search text := nullif(btrim(p_search), '');
  v_categoria text := nullif(btrim(p_categoria), '');
begin
  if v_actor_id is null then
    raise exception using errcode = '42501', message = 'Autenticação obrigatória.';
  end if;

  select a.cidade, a.estado
  into v_cidade, v_estado
  from public.usuarios u
  left join public.enderecos a on a.id = u.endereco_id
  where u.id = v_actor_id and u.ativo is true;
  if not found then
    raise exception using errcode = '42501', message = 'Usuário ativo é obrigatório.';
  end if;

  return query
  select s.id, s.empresa_id, s.nome, s.objetivo, s.foto_principal, s.categoria,
         s.link_anexo, s.nome_anexo, s.descricao, e.nome, e.foto_url,
         a.cidade, a.estado
  from public.empresa_servicos s
  join public.empresas e on e.id = s.empresa_id and e.ativo is true
  left join public.enderecos a on a.id = e.endereco_id
  where (p_empresa_id is null or s.empresa_id = p_empresa_id)
    and (v_search is null or s.nome ilike '%' || v_search || '%')
    and (v_categoria is null or v_categoria = 'Todos' or s.categoria = v_categoria)
  order by case
             when v_cidade is not null and v_estado is not null
              and lower(coalesce(a.cidade, '')) = lower(v_cidade)
              and lower(coalesce(a.estado, '')) = lower(v_estado) then 0
             when v_estado is not null
              and lower(coalesce(a.estado, '')) = lower(v_estado) then 1
             else 2
           end,
           lower(coalesce(s.nome, '')), s.id
  limit v_limit offset v_offset;
end;
$$;

revoke all on function public.list_public_company_services(uuid, text, text, integer, integer)
  from public, anon, authenticated;
grant execute on function public.list_public_company_services(uuid, text, text, integer, integer)
  to authenticated;
