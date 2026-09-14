-- DIAVICON - auditoria somente leitura de Home/Projetos.
-- Pode ser executada antes e depois da migration. Nenhum comando abaixo
-- altera dados, grants, policies ou funções.

begin transaction read only;

select current_database() as database_name,
       current_user as audit_role,
       current_setting('server_version') as postgres_version;

-- Tabelas esperadas, existência e estado de RLS/FORCE RLS.
with expected(schema_name, table_name) as (
  values
    ('public', 'usuarios'),
    ('public', 'empresas'),
    ('public', 'projetos'),
    ('public', 'status_projeto'),
    ('public', 'prioridade'),
    ('public', 'projeto_equipe_interna'),
    ('public', 'projeto_empresas_colaboradoras'),
    ('public', 'projeto_convites_cliente'),
    ('public', 'empresa_clientes'),
    ('public', 'notificacoes'),
    ('storage', 'objects')
)
select e.schema_name,
       e.table_name,
       c.oid is not null as exists,
       c.relrowsecurity as rls_enabled,
       c.relforcerowsecurity as force_rls
from expected e
left join pg_catalog.pg_namespace n on n.nspname = e.schema_name
left join pg_catalog.pg_class c
  on c.relnamespace = n.oid
 and c.relname = e.table_name
 and c.relkind in ('r', 'p')
order by e.schema_name, e.table_name;

-- Colunas esperadas ausentes. Resultado vazio é o esperado.
with required_columns(schema_name, table_name, column_name) as (
  values
    ('public', 'usuarios', 'id'),
    ('public', 'usuarios', 'empresa_id'),
    ('public', 'usuarios', 'ativo'),
    ('public', 'usuarios', 'is_admin_empresa'),
    ('public', 'usuarios', 'nome'),
    ('public', 'usuarios', 'sobrenome'),
    ('public', 'empresas', 'id'),
    ('public', 'empresas', 'nome'),
    ('public', 'projetos', 'id'),
    ('public', 'projetos', 'nome'),
    ('public', 'projetos', 'descricao'),
    ('public', 'projetos', 'empresa_gestora_id'),
    ('public', 'projetos', 'empresa_cliente_id'),
    ('public', 'projetos', 'status_vinculo_cliente'),
    ('public', 'projetos', 'status_id'),
    ('public', 'projetos', 'prioridade_id'),
    ('public', 'projetos', 'progresso'),
    ('public', 'projetos', 'image_url'),
    ('public', 'projetos', 'criado_por'),
    ('public', 'status_projeto', 'id'),
    ('public', 'status_projeto', 'nome'),
    ('public', 'prioridade', 'id'),
    ('public', 'prioridade', 'nome'),
    ('public', 'projeto_equipe_interna', 'projeto_id'),
    ('public', 'projeto_equipe_interna', 'usuario_id'),
    ('public', 'projeto_equipe_interna', 'empresa_id'),
    ('public', 'projeto_equipe_interna', 'ativo'),
    ('public', 'projeto_equipe_interna', 'is_gestor'),
    ('public', 'projeto_empresas_colaboradoras', 'id'),
    ('public', 'projeto_empresas_colaboradoras', 'projeto_id'),
    ('public', 'projeto_empresas_colaboradoras', 'empresa_id'),
    ('public', 'projeto_empresas_colaboradoras', 'criado_por'),
    ('public', 'projeto_empresas_colaboradoras', 'status'),
    ('public', 'projeto_convites_cliente', 'projeto_id'),
    ('public', 'projeto_convites_cliente', 'email_convidado'),
    ('public', 'projeto_convites_cliente', 'empresa_nome_temp'),
    ('public', 'projeto_convites_cliente', 'criado_por'),
    ('public', 'projeto_convites_cliente', 'aceito'),
    ('public', 'projeto_convites_cliente', 'foto_url'),
    ('public', 'empresa_clientes', 'gestora_id'),
    ('public', 'empresa_clientes', 'cliente_id'),
    ('public', 'empresa_clientes', 'status_vinculo'),
    ('public', 'notificacoes', 'id'),
    ('public', 'notificacoes', 'usuario_id'),
    ('public', 'notificacoes', 'titulo'),
    ('public', 'notificacoes', 'mensagem'),
    ('public', 'notificacoes', 'tipo'),
    ('public', 'notificacoes', 'lida'),
    ('public', 'notificacoes', 'dados_extras'),
    ('storage', 'objects', 'bucket_id'),
    ('storage', 'objects', 'name')
)
select r.*
from required_columns r
left join information_schema.columns c
  on c.table_schema = r.schema_name
 and c.table_name = r.table_name
 and c.column_name = r.column_name
where c.column_name is null
order by r.schema_name, r.table_name, r.column_name;

-- Todas as policies do escopo. Policies sem prefixo dv_ precisam de revisão;
-- elas são preservadas pela migration e uma RESTRICTIVE antiga pode bloquear.
select schemaname,
       tablename,
       policyname,
       permissive,
       roles,
       cmd,
       qual,
       with_check
from pg_catalog.pg_policies
where (schemaname = 'public' and tablename in (
         'projetos',
         'projeto_equipe_interna',
         'projeto_empresas_colaboradoras',
         'projeto_convites_cliente',
         'empresa_clientes',
         'notificacoes'
       ))
   or (schemaname = 'storage' and tablename = 'objects')
order by schemaname, tablename, policyname;

-- Segurança e assinatura das RPCs/helpers.
select n.nspname as function_schema,
       p.proname as function_name,
       pg_catalog.pg_get_function_identity_arguments(p.oid) as arguments,
       pg_catalog.pg_get_function_result(p.oid) as result,
       p.prosecdef as security_definer,
       p.proconfig,
       p.proacl
from pg_catalog.pg_proc p
join pg_catalog.pg_namespace n on n.oid = p.pronamespace
where (n.nspname = 'public' and p.proname in (
         'create_project',
         'update_project',
         'invite_project_company',
         'respond_to_project_company_invite',
         'transfer_project_management',
         'invite_project_client',
         'respond_to_project_client_invite',
         'remove_project_client',
         'delete_project'
       ))
   or (n.nspname = 'app_private' and p.proname like 'dv\_%' escape '\')
   or (n.nspname = 'app_private' and p.proname in (
         'current_company_id',
         'is_company_admin',
         'is_company_admin_user',
         'has_project_access',
         'can_edit_project',
         'can_manage_project',
         'can_manage_company_team',
         'is_valid_team_member'
       ))
order by n.nspname, p.proname, arguments;

-- Grants efetivos declarados diretamente para anon/authenticated/PUBLIC.
select grantor, grantee, table_schema, table_name, privilege_type
from information_schema.role_table_grants
where table_schema in ('public', 'storage')
  and table_name in (
    'projetos',
    'projeto_equipe_interna',
    'projeto_empresas_colaboradoras',
    'projeto_convites_cliente',
    'empresa_clientes',
    'notificacoes',
    'objects'
  )
  and grantee in ('PUBLIC', 'anon', 'authenticated')
order by table_schema, table_name, grantee, privilege_type;

select grantor, grantee, table_schema, table_name, column_name, privilege_type
from information_schema.column_privileges
where table_schema = 'public'
  and table_name in (
    'projetos',
    'projeto_equipe_interna',
    'projeto_empresas_colaboradoras',
    'projeto_convites_cliente',
    'empresa_clientes',
    'notificacoes'
  )
  and grantee in ('PUBLIC', 'anon', 'authenticated')
order by table_name, grantee, privilege_type, column_name;

-- Integridade que precisa retornar zero em todas as linhas.
select 'duplicate_project_user' as finding, count(*) as violations
from (
  select projeto_id, usuario_id
  from public.projeto_equipe_interna
  group by projeto_id, usuario_id
  having count(*) > 1
) d
union all
select 'duplicate_project_company', count(*)
from (
  select projeto_id, empresa_id
  from public.projeto_empresas_colaboradoras
  group by projeto_id, empresa_id
  having count(*) > 1
) d
union all
select 'duplicate_manager_client', count(*)
from (
  select gestora_id, cliente_id
  from public.empresa_clientes
  group by gestora_id, cliente_id
  having count(*) > 1
) d
union all
select 'duplicate_project_status_name', count(*)
from (
  select lower(btrim(nome))
  from public.status_projeto
  group by lower(btrim(nome))
  having count(*) > 1
) d
union all
select 'duplicate_project_priority_name', count(*)
from (
  select lower(btrim(nome))
  from public.prioridade
  group by lower(btrim(nome))
  having count(*) > 1
) d
union all
select 'invalid_collaboration_status', count(*)
from public.projeto_empresas_colaboradoras
where status is null
   or status not in ('pendente', 'aceito', 'recusado', 'removida')
union all
select 'team_company_mismatch', count(*)
from public.projeto_equipe_interna pei
left join public.usuarios u on u.id = pei.usuario_id
where u.id is null or u.empresa_id is distinct from pei.empresa_id
union all
select 'invalid_scoped_project_storage_path', count(*)
from storage.objects o
where o.bucket_id = 'projetos'
  and (storage.foldername(o.name))[1] = 'users'
  and (storage.foldername(o.name))[3] in ('capas', 'clientes')
  and (
    (storage.foldername(o.name))[2] is not null
    and (storage.foldername(o.name))[3] in ('capas', 'clientes')
    and (storage.foldername(o.name))[4] is null
  ) is not true;

-- A coluna public determina se getPublicUrl expõe os objetos sem JWT.
select id, name, public
from storage.buckets
where id = 'projetos';

commit;
