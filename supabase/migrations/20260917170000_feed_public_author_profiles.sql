-- The feed_posts client query embeds usuarios(nome, foto_url, empresas(nome,
-- foto_url)) to show the author's name/photo and company on every post. RLS
-- on usuarios (auth_users_select_own: id = auth.uid()) and empresas
-- (auth_companies_select_member: same company only) only let each viewer
-- read their OWN row, so that embed resolves to null for every post whose
-- author isn't the current user — the client then falls back to "Empresa
-- Desconhecida"/"Usuário". The feed is meant to show any active user's
-- public name/photo and their company's public name/photo across companies,
-- same as list_public_companies() already does for company discovery — so
-- this exposes just those fields via a SECURITY DEFINER function instead of
-- widening the usuarios/empresas RLS policies (which would also expose
-- email, celular, is_admin, etc. to any authenticated user).

begin;

create or replace function public.get_perfis_feed(p_usuario_ids uuid[])
returns table (
  usuario_id uuid,
  nome text,
  foto_url text,
  empresa_nome text,
  empresa_foto_url text
)
language sql
security definer
stable
set search_path = public, pg_catalog
as $$
  select u.id, u.nome, u.foto_url, e.nome, e.foto_url
  from public.usuarios u
  left join public.empresas e on e.id = u.empresa_id
  where u.id = any(p_usuario_ids)
    and u.ativo is true;
$$;

revoke all on function public.get_perfis_feed(uuid[]) from public, anon;
grant execute on function public.get_perfis_feed(uuid[]) to authenticated;

commit;
