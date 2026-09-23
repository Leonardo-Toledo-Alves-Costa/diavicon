-- Galeria de fotos do RDO — opcional, o usuário anexa quantas quiser após
-- salvar o RDO. Mesmo padrão de `galeria_pontos_ensaios_geral` (foto +
-- descrição por linha), mas com nomes de coluna próprios (foto/descricao).

create table public.rdo_galeria (
  id uuid not null default gen_random_uuid(),
  criado_em timestamp with time zone not null default now(),
  foto text,
  descricao text,
  rdo_id uuid default gen_random_uuid(),
  constraint rdo_galeria_pkey primary key (id),
  constraint rdo_galeria_rdo_id_fkey foreign key (rdo_id) references public.rdo_realizado(id)
);

create index rdo_galeria_rdo_id_idx on public.rdo_galeria (rdo_id);

alter table public.rdo_galeria enable row level security;

-- Mesma regra de visibilidade do próprio RDO: quem pode ver o rdo_realizado
-- (dono, gestora, ou cliente ativo do projeto) pode ver a galeria dele.
create policy rdo_galeria_select
on public.rdo_galeria
for select to authenticated
using (
  exists (
    select 1 from public.rdo_realizado r where r.id = rdo_galeria.rdo_id
  )
);

-- Escrita: só quem pode editar o RDO dono da foto (o próprio autor ou a
-- gestora do projeto) — o cliente nunca anexa fotos, só revisa.
create policy rdo_galeria_insert
on public.rdo_galeria
for insert to authenticated
with check (
  exists (
    select 1
    from public.rdo_realizado r
    where r.id = rdo_galeria.rdo_id
      and (
        r.empresa_id = private.active_actor_company_id()
        or exists (
          select 1 from public.projetos p
          where p.id = r.projeto_id
            and p.empresa_gestora_id = private.active_actor_company_id()
        )
      )
  )
);

create policy rdo_galeria_update
on public.rdo_galeria
for update to authenticated
using (
  exists (
    select 1
    from public.rdo_realizado r
    where r.id = rdo_galeria.rdo_id
      and (
        r.empresa_id = private.active_actor_company_id()
        or exists (
          select 1 from public.projetos p
          where p.id = r.projeto_id
            and p.empresa_gestora_id = private.active_actor_company_id()
        )
      )
  )
)
with check (
  exists (
    select 1
    from public.rdo_realizado r
    where r.id = rdo_galeria.rdo_id
      and (
        r.empresa_id = private.active_actor_company_id()
        or exists (
          select 1 from public.projetos p
          where p.id = r.projeto_id
            and p.empresa_gestora_id = private.active_actor_company_id()
        )
      )
  )
);

create policy rdo_galeria_delete
on public.rdo_galeria
for delete to authenticated
using (
  exists (
    select 1
    from public.rdo_realizado r
    where r.id = rdo_galeria.rdo_id
      and (
        r.empresa_id = private.active_actor_company_id()
        or exists (
          select 1 from public.projetos p
          where p.id = r.projeto_id
            and p.empresa_gestora_id = private.active_actor_company_id()
        )
      )
  )
);
