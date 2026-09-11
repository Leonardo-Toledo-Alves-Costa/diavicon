begin;

-- These tables already have scoped policies from the authentication, catalog,
-- and company-feed migrations. The production catalog had those policies but
-- RLS itself was disabled, so enable the existing security boundary.
alter table public.empresa_servicos enable row level security;
alter table public.empresa_servicos_galeria enable row level security;
alter table public.empresas enable row level security;
alter table public.enderecos enable row level security;
alter table public.planos enable row level security;
alter table public.tipologias_local enable row level security;
alter table public.tipos_elemento enable row level security;
alter table public.tipos_ensaio enable row level security;
alter table public.tipos_ensaio_parametros enable row level security;
alter table public.tipos_estrutura enable row level security;
alter table public.usuarios enable row level security;
alter table public.utilizacoes_estrutura enable row level security;

commit;
