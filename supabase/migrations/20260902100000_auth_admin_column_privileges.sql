-- Keep authorization fields writable only by trusted server-side operations.
-- Safe profile fields remain available to the authenticated owner.

revoke insert on public.usuarios from authenticated;
revoke update on public.usuarios from authenticated;

grant insert (
  id,
  nome,
  sobrenome,
  email,
  celular,
  cargo,
  setor_id,
  titulo_principal,
  escolaridade,
  foto_url,
  linkedin,
  instagram,
  perfil,
  endereco_id
) on public.usuarios to authenticated;

grant update (
  nome,
  sobrenome,
  email,
  celular,
  cargo,
  setor_id,
  titulo_principal,
  escolaridade,
  foto_url,
  linkedin,
  instagram,
  perfil,
  endereco_id
) on public.usuarios to authenticated;
