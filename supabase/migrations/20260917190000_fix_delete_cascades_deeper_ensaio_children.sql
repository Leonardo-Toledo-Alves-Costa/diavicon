-- Continuação de 20260917180000: um teste real (rollback-wrapped) de exclusão
-- de estrutura revelou um segundo nível de tabelas-filhas que também
-- bloqueavam a exclusão — filhas de `ponto_inspecao_visual` (anomalias,
-- galeria, região/marcação em planta) e de outras famílias de ensaio
-- (arrancamento, carbonatação, potencial de corrosão) que têm suas próprias
-- tabelas de leitura/detalhe um nível abaixo da que já foi corrigida.

begin;

alter table public.estruturas_plantas
  drop constraint estruturas_plantas_local_id_fkey,
  add constraint estruturas_plantas_local_id_fkey
    foreign key (local_id) references public.estruturas_locais(id) on delete cascade;

alter table public.ponto_inspecao_regiao
  drop constraint ponto_inspecao_regiao_planta_id_fkey,
  add constraint ponto_inspecao_regiao_planta_id_fkey
    foreign key (planta_id) references public.estruturas_plantas(id) on delete cascade;

alter table public.ponto_inspecao_regiao
  drop constraint ponto_inspecao_regiao_ponto_id_fkey,
  add constraint ponto_inspecao_regiao_ponto_id_fkey
    foreign key (ponto_id) references public.ponto_inspecao_visual(id) on delete cascade;

alter table public.ponto_inspecao_visual
  drop constraint ponto_inspecao_visual_id_local_fkey,
  add constraint ponto_inspecao_visual_id_local_fkey
    foreign key (id_local) references public.estruturas_locais(id) on delete cascade;

alter table public.ponto_inspecao_visual
  drop constraint ponto_inspecao_visual_id_ponto_geral_fkey,
  add constraint ponto_inspecao_visual_id_ponto_geral_fkey
    foreign key (id_ponto_geral) references public.ponto_inspecao_visual_geral(id) on delete cascade;

alter table public.ponto_inspecao_visual_anomalia
  drop constraint ponto_inspecao_visual_anomalia_id_inspecao_fkey,
  add constraint ponto_inspecao_visual_anomalia_id_inspecao_fkey
    foreign key (id_inspecao) references public.ponto_inspecao_visual(id) on delete cascade;

alter table public.ponto_inspecao_visual_galeria
  drop constraint ponto_inspecao_visual_galeria_id_inspecao_fkey,
  add constraint ponto_inspecao_visual_galeria_id_inspecao_fkey
    foreign key (id_inspecao) references public.ponto_inspecao_visual(id) on delete cascade;

alter table public.galeria_ponto_ensaio_carb
  drop constraint galeria_ponto_ensaio_carb_ponto_ensaio_id_fkey,
  add constraint galeria_ponto_ensaio_carb_ponto_ensaio_id_fkey
    foreign key (ponto_ensaio_id) references public.ponto_ensaio_carb(id) on delete cascade;

alter table public.ponto_ensaio_arrancamento_leitura
  drop constraint ponto_ensaio_arrancamento_leitura_id_ponto_arrancamento_fkey,
  add constraint ponto_ensaio_arrancamento_leitura_id_ponto_arrancamento_fkey
    foreign key (id_ponto_arrancamento) references public.ponto_ensaio_arrancamento(id) on delete cascade;

alter table public.ponto_ensaio_arrancamento_ruptura
  drop constraint ponto_ensaio_arrancamento_ruptura_id_ponto_leitura_fkey,
  add constraint ponto_ensaio_arrancamento_ruptura_id_ponto_leitura_fkey
    foreign key (id_ponto_leitura) references public.ponto_ensaio_arrancamento_leitura(id) on delete cascade;

alter table public.ponto_ensaio_carb_frentes
  drop constraint ponto_ensaio_carb_frentes_ponto_ensaio_id_fkey,
  add constraint ponto_ensaio_carb_frentes_ponto_ensaio_id_fkey
    foreign key (ponto_ensaio_id) references public.ponto_ensaio_carb(id) on delete cascade;

alter table public.ponto_ensaio_potencial_leitura
  drop constraint ponto_ensaio_potencial_leitura_ponto_potencial_id_fkey,
  add constraint ponto_ensaio_potencial_leitura_ponto_potencial_id_fkey
    foreign key (ponto_potencial_id) references public.ponto_ensaio_potencial(id) on delete cascade;

-- Leitura de potencial pode referenciar a leitura de resistividade
-- correspondente (correlação entre os dois ensaios); como resistividade já
-- cascateia de pontos_ensaios_geral, essa referência cruzada tem que
-- acompanhar, senão bloqueia a exclusão quando ambos os ensaios existem no
-- mesmo ponto/estrutura.
alter table public.ponto_ensaio_potencial_leitura
  drop constraint ponto_ensaio_potencial_leitura_id_leitura_resistividade_fkey,
  add constraint ponto_ensaio_potencial_leitura_id_leitura_resistividade_fkey
    foreign key (id_leitura_resistividade) references public.ponto_ensaio_resistividade_leitura(id) on delete cascade;

commit;
