-- Rastreio de autoria em elementos estruturais.
--
-- `elementos_estruturais` é uma das cinco tabelas estruturais que seguem sem
-- RLS (ver o cabeçalho de 20260909100000_remaining_rls.sql), então o
-- preenchimento de `criado_por` fica a cargo de um trigger em vez de uma
-- policy: o cliente não escolhe o autor, e o valor não pode ser trocado
-- depois. Mesmo padrão de private.enforce_region_update().
--
-- A coluna é nullable de propósito: os elementos criados antes desta
-- migration não têm autor conhecido e precisam continuar funcionando em
-- branco — nem a leitura nem a edição podem quebrar por causa disso.

begin;

alter table public.elementos_estruturais
  add column if not exists criado_por uuid;

-- ON DELETE SET NULL pelo mesmo motivo de 20260917220000: excluir um
-- colaborador não pode travar na FK nem apagar o elemento que ele criou —
-- só desvincula o autor.
alter table public.elementos_estruturais
  drop constraint if exists elementos_estruturais_criado_por_fkey;

alter table public.elementos_estruturais
  add constraint elementos_estruturais_criado_por_fkey
    foreign key (criado_por) references public.usuarios(id) on delete set null;

create index if not exists elementos_estruturais_criado_por_idx
  on public.elementos_estruturais (criado_por);

create or replace function private.set_elemento_author()
returns trigger
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
begin
  if tg_op = 'INSERT' then
    -- auth.uid() é null em rotas de serviço (seed, service_role): nesses
    -- casos o elemento entra sem autor, em vez de falhar o insert.
    if (select auth.uid()) is not null then
      new.criado_por := (select auth.uid());
    end if;
  elsif tg_op = 'UPDATE' then
    -- Autoria é histórico: nunca muda. Restaura em silêncio em vez de
    -- levantar exceção porque `atualizarElemento` manda o elemento inteiro
    -- de volta — levantar aqui quebraria toda edição de elemento por um
    -- campo que o usuário nem edita. Elemento antigo sem autor continua sem.
    new.criado_por := old.criado_por;
  end if;
  return new;
end;
$$;

drop trigger if exists set_elemento_author on public.elementos_estruturais;
create trigger set_elemento_author
  before insert or update on public.elementos_estruturais
  for each row execute function private.set_elemento_author();

commit;
