-- Permite que um administrador conceda a um colaborador comum acesso só de
-- VISUALIZAÇÃO ao painel da empresa (hoje só quem é `is_admin_empresa` — o
-- gestor principal — vê o botão "Painel" em empresa_profile_screen.dart).
-- Segue o mesmo padrão de is_admin/is_admin_empresa: coluna gravável apenas
-- pelo lado servidor (Edge Function `auth-operations`, operação
-- 'set_pode_visualizar'), nunca pelo GRANT UPDATE direto do cliente.

begin;

alter table public.usuarios
  add column if not exists pode_visualizar_empresa boolean not null default false;

commit;
