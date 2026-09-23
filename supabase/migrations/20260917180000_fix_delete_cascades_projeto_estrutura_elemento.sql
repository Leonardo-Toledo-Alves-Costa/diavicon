-- Corrige o comportamento de exclusão de Projeto / Estrutura / Elemento.
--
-- Um arquivo em supabase/migrations_manual/cascade_delete_projeto_estrutura_elemento.sql
-- afirmava (em comentários no app Dart) que esse cascade já estava aplicado —
-- não estava: inspecionando o banco ao vivo, praticamente todo o caminho de
-- pontos_ensaios_geral -> projetos/estruturas/elementos_estruturais era
-- RESTRICT/NO ACTION, então hoje excluir um projeto, estrutura ou elemento
-- que já tenha QUALQUER ponto de ensaio falha com violação de FK (e o mesmo
-- vale pra excluir uma estrutura com locais/plantas cadastrados, que é
-- basicamente toda estrutura real).
--
-- Regra pedida:
--   - Apagar um PROJETO:   não apaga conjunto estrutural, nem estrutura, nem
--                          elementos — mas apaga todos os pontos de ensaio
--                          ligados a ele (não há FK de projetos pra
--                          conjuntos_estruturais/estruturas, então essa parte
--                          já é garantida só pelo cascade abaixo não tocar
--                          nessas tabelas).
--   - Apagar uma ESTRUTURA: apaga elementos estruturais e pontos de ensaio
--                          vinculados a ela (elementos_estruturais.estrutura_id
--                          já era CASCADE; o resto não era).
--   - Apagar um ELEMENTO:   apaga os pontos de ensaio ligados a ele.
--
-- "Pontos de ensaio" cobre tanto a tabela guarda-chuva pontos_ensaios_geral
-- quanto as tabelas de detalhe por tipo de ensaio (uma por família) e seus
-- links diretos redundantes pra projeto/estrutura/elemento.

begin;

-- ── A. pontos_ensaios_geral -> projeto/estrutura/elemento (o cascade raiz) ──
alter table public.pontos_ensaios_geral
  drop constraint pontos_ensaios_geral_id_projeto_fkey,
  add constraint pontos_ensaios_geral_id_projeto_fkey
    foreign key (projeto_id) references public.projetos(id) on delete cascade;

alter table public.pontos_ensaios_geral
  drop constraint pontos_ensaios_geral_estrutura_id_fkey,
  add constraint pontos_ensaios_geral_estrutura_id_fkey
    foreign key (estrutura_id) references public.estruturas(id) on delete cascade;

alter table public.pontos_ensaios_geral
  drop constraint pontos_ensaios_geral_id_elemento_estrutural_fkey,
  add constraint pontos_ensaios_geral_id_elemento_estrutural_fkey
    foreign key (elemento_estrutural_id) references public.elementos_estruturais(id) on delete cascade;

-- ── B. Tabelas de detalhe por ensaio -> pontos_ensaios_geral ──
-- (esclerometria, extração, monitoramento de fissura, prova de carga, tração
-- e ultrassom já eram CASCADE — só faltavam estas.)
alter table public.galeria_ponto_ensaio_resistividade
  drop constraint galeria_ponto_ensaio_resistividade_ponto_ensaio_id_fkey,
  add constraint galeria_ponto_ensaio_resistividade_ponto_ensaio_id_fkey
    foreign key (ponto_ensaio_id) references public.pontos_ensaios_geral(id) on delete cascade;

alter table public.galeria_pontos_ensaios_geral
  drop constraint galeria_pontos_ensaios_geral_ponto_ensaio_id_fkey,
  add constraint galeria_pontos_ensaios_geral_ponto_ensaio_id_fkey
    foreign key (ponto_ensaio_id) references public.pontos_ensaios_geral(id) on delete cascade;

alter table public.ponto_ensaio_arrancamento
  drop constraint "Ponto_ensaio_arrancamento_ponto_ensaio_id_fkey",
  add constraint "Ponto_ensaio_arrancamento_ponto_ensaio_id_fkey"
    foreign key (ponto_ensaio_id) references public.pontos_ensaios_geral(id) on delete cascade;

alter table public.ponto_ensaio_carb
  drop constraint ponto_ensaio_carb_ponto_ensaio_id_fkey,
  add constraint ponto_ensaio_carb_ponto_ensaio_id_fkey
    foreign key (ponto_ensaio_id) references public.pontos_ensaios_geral(id) on delete cascade;

alter table public.ponto_ensaio_potencial
  drop constraint ponto_ensaio_potencial_ponto_ensaio_id_fkey,
  add constraint ponto_ensaio_potencial_ponto_ensaio_id_fkey
    foreign key (ponto_ensaio_id) references public.pontos_ensaios_geral(id) on delete cascade;

alter table public.ponto_ensaio_resistividade_leitura
  drop constraint ponto_ensaio_resistividade_leitura_id_ponto_geral_fkey,
  add constraint ponto_ensaio_resistividade_leitura_id_ponto_geral_fkey
    foreign key (id_ponto_geral) references public.pontos_ensaios_geral(id) on delete cascade;

alter table public.ponto_inspecao_visual_geral
  drop constraint ponto_inspecao_visual_geral_id_ponto_geral_fkey,
  add constraint ponto_inspecao_visual_geral_id_ponto_geral_fkey
    foreign key (id_ponto_geral) references public.pontos_ensaios_geral(id) on delete cascade;

-- ── C. Links diretos redundantes de tabelas de ensaio pra projeto/estrutura/elemento ──
alter table public.ponto_ensaio_carb
  drop constraint ponto_ensaio_carb_id_elemento_estrutural_fkey,
  add constraint ponto_ensaio_carb_id_elemento_estrutural_fkey
    foreign key (elemento_estrutural_id) references public.elementos_estruturais(id) on delete cascade;

alter table public.ponto_ensaio_carb
  drop constraint ponto_ensaio_carb_id_projeto_fkey,
  add constraint ponto_ensaio_carb_id_projeto_fkey
    foreign key (projeto_id) references public.projetos(id) on delete cascade;

alter table public.ponto_ensaio_prova_carga
  drop constraint ponto_ensaio_prova_carga_elemento_id_fkey,
  add constraint ponto_ensaio_prova_carga_elemento_id_fkey
    foreign key (elemento_id) references public.elementos_estruturais(id) on delete cascade;

alter table public.ponto_inspecao_visual
  drop constraint ponto_inspecao_visual_id_elemento_fkey,
  add constraint ponto_inspecao_visual_id_elemento_fkey
    foreign key (id_elemento) references public.elementos_estruturais(id) on delete cascade;

alter table public.ponto_inspecao_visual
  drop constraint ponto_inspecao_visual_id_estrutura_fkey,
  add constraint ponto_inspecao_visual_id_estrutura_fkey
    foreign key (id_estrutura) references public.estruturas(id) on delete cascade;

alter table public.ponto_inspecao_visual
  drop constraint ponto_inspecao_visual_id_projeto_fkey,
  add constraint ponto_inspecao_visual_id_projeto_fkey
    foreign key (id_projeto) references public.projetos(id) on delete cascade;

-- ── D. Dados da própria estrutura (pré-requisito: sem isso, excluir QUALQUER
-- estrutura com local ou planta cadastrada — ou seja, praticamente todas —
-- já falhava antes mesmo de chegar nos elementos/pontos de ensaio) ──
alter table public.estruturas_locais
  drop constraint estruturas_locais_estrutura_id_fkey,
  add constraint estruturas_locais_estrutura_id_fkey
    foreign key (estrutura_id) references public.estruturas(id) on delete cascade;

alter table public.estruturas_plantas
  drop constraint estruturas_plantas_estrutura_id_fkey,
  add constraint estruturas_plantas_estrutura_id_fkey
    foreign key (estrutura_id) references public.estruturas(id) on delete cascade;

-- ── E. Relatórios e convites ligados ao projeto/estrutura ──
-- `relatorios.projeto_id` é opcional (nullable): preserva o relatório como
-- histórico, só desvincula do projeto apagado. `relatorio_ensaio` é NOT NULL
-- nas duas colunas (é uma tabela de detalhe, não um registro independente),
-- então só pode ir junto (cascade) — não dá pra deixar nulo.
alter table public.relatorios
  drop constraint relatorios_projeto_id_fkey,
  add constraint relatorios_projeto_id_fkey
    foreign key (projeto_id) references public.projetos(id) on delete set null;

alter table public.relatorio_ensaio
  drop constraint relatorio_ensaio_projeto_id_fkey,
  add constraint relatorio_ensaio_projeto_id_fkey
    foreign key (projeto_id) references public.projetos(id) on delete cascade;

alter table public.relatorio_ensaio
  drop constraint relatorio_ensaio_estrutura_id_fkey,
  add constraint relatorio_ensaio_estrutura_id_fkey
    foreign key (estrutura_id) references public.estruturas(id) on delete cascade;

alter table public.projeto_convites_cliente
  drop constraint projeto_convites_cliente_projeto_id_fkey,
  add constraint projeto_convites_cliente_projeto_id_fkey
    foreign key (projeto_id) references public.projetos(id) on delete cascade;

commit;
