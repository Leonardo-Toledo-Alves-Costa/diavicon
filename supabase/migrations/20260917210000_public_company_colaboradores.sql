-- A tela 'Empresas' já deixa qualquer empresa autenticada ver o perfil
-- público de outra (get_public_company/list_public_company_services), mas a
-- seção "Colaboradores" desse perfil ficava sempre vazia pra qualquer
-- empresa que não fosse a própria: o provider Flutter (`empresaColaboradoresProvider`)
-- tinha um guard client-side que só chamava a busca quando `empresaId ==
-- minha própria empresa`, e a Edge Function por trás dela
-- (`list_company_colleagues`) nem aceita um id de empresa alvo — sempre
-- devolve os colegas da PRÓPRIA empresa de quem chama. Segue o mesmo padrão
-- já usado pra expor dado público de usuário entre empresas
-- (get_perfis_feed): uma function SECURITY DEFINER só com campos não
-- sensíveis (nome/sobrenome/cargo/foto), nunca email/celular/is_admin etc.

begin;

create or replace function public.get_public_company_colaboradores(p_empresa_id uuid)
returns table (
  usuario_id uuid,
  nome text,
  sobrenome text,
  cargo text,
  foto_url text
)
language sql
security definer
stable
set search_path = public, pg_catalog
as $$
  select u.id, u.nome, u.sobrenome, u.cargo, u.foto_url
  from public.usuarios u
  where u.empresa_id = p_empresa_id
    and u.ativo is true
    and exists (
      select 1 from public.usuarios me
      where me.id = (select auth.uid()) and me.ativo is true
    )
  order by u.nome;
$$;

revoke all on function public.get_public_company_colaboradores(uuid) from public, anon;
grant execute on function public.get_public_company_colaboradores(uuid) to authenticated;

commit;
