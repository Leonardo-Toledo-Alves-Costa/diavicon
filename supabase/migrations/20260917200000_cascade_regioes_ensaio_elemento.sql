-- `regioes_ensaio` guarda a marcação/região de um ensaio numa planta baixa,
-- vinculada opcionalmente a um elemento (`elemento_id`). Era ON DELETE SET
-- NULL — ao excluir o elemento, a região de ensaio sobrevivia órfã (sem
-- elemento) em vez de ser removida. Pedido explícito: excluir um elemento
-- deve apagar também as regiões/marcações de ensaio vinculadas a ele.

begin;

alter table public.regioes_ensaio
  drop constraint fk_regiao_elemento,
  add constraint fk_regiao_elemento
    foreign key (elemento_id) references public.elementos_estruturais(id) on delete cascade;

commit;
