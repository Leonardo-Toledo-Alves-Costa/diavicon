-- ============================================================================
-- Migration manual: ON DELETE CASCADE para a cadeia
-- Projeto -> Estrutura -> Elemento Estrutural -> pontos_ensaios_geral -> tabelas de cada ensaio
--
-- Objetivo: permitir excluir um Projeto/Estrutura/Elemento Estrutural direto
-- (DELETE FROM ...) e deixar o Postgres cuidar de apagar tudo que depende
-- dele, em vez de orquestrar dezenas de deletes manualmente no app. Sem isso,
-- qualquer tentativa de excluir um elemento/estrutura/projeto que já tenha
-- ensaios cadastrados falha com erro de violação de chave estrangeira.
--
-- Seguro rodar mais de uma vez (usa DROP CONSTRAINT IF EXISTS antes de recriar).
-- Revise com calma antes de rodar em produção -- é uma mudança estrutural.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. Estrutura -> Elemento Estrutural / Local / Planta
-- ---------------------------------------------------------------------------
ALTER TABLE public.elementos_estruturais DROP CONSTRAINT IF EXISTS elementos_estruturais_estrutura_id_fkey;
ALTER TABLE public.elementos_estruturais ADD CONSTRAINT elementos_estruturais_estrutura_id_fkey
  FOREIGN KEY (estrutura_id) REFERENCES public.estruturas(id) ON DELETE CASCADE;

ALTER TABLE public.estruturas_locais DROP CONSTRAINT IF EXISTS estruturas_locais_estrutura_id_fkey;
ALTER TABLE public.estruturas_locais ADD CONSTRAINT estruturas_locais_estrutura_id_fkey
  FOREIGN KEY (estrutura_id) REFERENCES public.estruturas(id) ON DELETE CASCADE;

ALTER TABLE public.estruturas_plantas DROP CONSTRAINT IF EXISTS estruturas_plantas_estrutura_id_fkey;
ALTER TABLE public.estruturas_plantas ADD CONSTRAINT estruturas_plantas_estrutura_id_fkey
  FOREIGN KEY (estrutura_id) REFERENCES public.estruturas(id) ON DELETE CASCADE;

ALTER TABLE public.regioes_ensaio DROP CONSTRAINT IF EXISTS fk_regiao_planta;
ALTER TABLE public.regioes_ensaio ADD CONSTRAINT fk_regiao_planta
  FOREIGN KEY (planta_id) REFERENCES public.estruturas_plantas(id) ON DELETE CASCADE;

-- Referência secundária (não é a posse principal do registro) -> zera em vez de apagar a região.
ALTER TABLE public.regioes_ensaio DROP CONSTRAINT IF EXISTS fk_regiao_elemento;
ALTER TABLE public.regioes_ensaio ADD CONSTRAINT fk_regiao_elemento
  FOREIGN KEY (elemento_id) REFERENCES public.elementos_estruturais(id) ON DELETE SET NULL;

ALTER TABLE public.ensaios_contratados DROP CONSTRAINT IF EXISTS fk_ensaio_contratado_estrutura;
ALTER TABLE public.ensaios_contratados ADD CONSTRAINT fk_ensaio_contratado_estrutura
  FOREIGN KEY (estrutura_id) REFERENCES public.estruturas(id) ON DELETE CASCADE;

ALTER TABLE public.ensaios_contratados DROP CONSTRAINT IF EXISTS ensaios_contratados_projeto_id_fkey;
ALTER TABLE public.ensaios_contratados ADD CONSTRAINT ensaios_contratados_projeto_id_fkey
  FOREIGN KEY (projeto_id) REFERENCES public.projetos(id) ON DELETE CASCADE;

ALTER TABLE public.ensaios_contratados DROP CONSTRAINT IF EXISTS ensaios_contratados_regiao_id_fkey;
ALTER TABLE public.ensaios_contratados ADD CONSTRAINT ensaios_contratados_regiao_id_fkey
  FOREIGN KEY (regiao_id) REFERENCES public.regioes_ensaio(id) ON DELETE CASCADE;

ALTER TABLE public.relatorio_ensaio DROP CONSTRAINT IF EXISTS relatorio_ensaio_estrutura_id_fkey;
ALTER TABLE public.relatorio_ensaio ADD CONSTRAINT relatorio_ensaio_estrutura_id_fkey
  FOREIGN KEY (estrutura_id) REFERENCES public.estruturas(id) ON DELETE CASCADE;

-- ---------------------------------------------------------------------------
-- 2. Elemento Estrutural / Estrutura / Projeto -> pontos_ensaios_geral (raiz comum de todo ensaio)
-- ---------------------------------------------------------------------------
ALTER TABLE public.pontos_ensaios_geral DROP CONSTRAINT IF EXISTS pontos_ensaios_geral_id_elemento_estrutural_fkey;
ALTER TABLE public.pontos_ensaios_geral ADD CONSTRAINT pontos_ensaios_geral_id_elemento_estrutural_fkey
  FOREIGN KEY (elemento_estrutural_id) REFERENCES public.elementos_estruturais(id) ON DELETE CASCADE;

ALTER TABLE public.pontos_ensaios_geral DROP CONSTRAINT IF EXISTS pontos_ensaios_geral_estrutura_id_fkey;
ALTER TABLE public.pontos_ensaios_geral ADD CONSTRAINT pontos_ensaios_geral_estrutura_id_fkey
  FOREIGN KEY (estrutura_id) REFERENCES public.estruturas(id) ON DELETE CASCADE;

ALTER TABLE public.pontos_ensaios_geral DROP CONSTRAINT IF EXISTS pontos_ensaios_geral_id_projeto_fkey;
ALTER TABLE public.pontos_ensaios_geral ADD CONSTRAINT pontos_ensaios_geral_id_projeto_fkey
  FOREIGN KEY (projeto_id) REFERENCES public.projetos(id) ON DELETE CASCADE;

ALTER TABLE public.galeria_pontos_ensaios_geral DROP CONSTRAINT IF EXISTS galeria_pontos_ensaios_geral_ponto_ensaio_id_fkey;
ALTER TABLE public.galeria_pontos_ensaios_geral ADD CONSTRAINT galeria_pontos_ensaios_geral_ponto_ensaio_id_fkey
  FOREIGN KEY (ponto_ensaio_id) REFERENCES public.pontos_ensaios_geral(id) ON DELETE CASCADE;

-- ---------------------------------------------------------------------------
-- 3. Carbonatação
-- ---------------------------------------------------------------------------
ALTER TABLE public.ponto_ensaio_carb DROP CONSTRAINT IF EXISTS ponto_ensaio_carb_ponto_ensaio_id_fkey;
ALTER TABLE public.ponto_ensaio_carb ADD CONSTRAINT ponto_ensaio_carb_ponto_ensaio_id_fkey
  FOREIGN KEY (ponto_ensaio_id) REFERENCES public.pontos_ensaios_geral(id) ON DELETE CASCADE;

ALTER TABLE public.ponto_ensaio_carb DROP CONSTRAINT IF EXISTS ponto_ensaio_carb_id_elemento_estrutural_fkey;
ALTER TABLE public.ponto_ensaio_carb ADD CONSTRAINT ponto_ensaio_carb_id_elemento_estrutural_fkey
  FOREIGN KEY (elemento_estrutural_id) REFERENCES public.elementos_estruturais(id) ON DELETE CASCADE;

ALTER TABLE public.ponto_ensaio_carb DROP CONSTRAINT IF EXISTS ponto_ensaio_carb_id_projeto_fkey;
ALTER TABLE public.ponto_ensaio_carb ADD CONSTRAINT ponto_ensaio_carb_id_projeto_fkey
  FOREIGN KEY (projeto_id) REFERENCES public.projetos(id) ON DELETE CASCADE;

ALTER TABLE public.galeria_ponto_ensaio_carb DROP CONSTRAINT IF EXISTS galeria_ponto_ensaio_carb_ponto_ensaio_id_fkey;
ALTER TABLE public.galeria_ponto_ensaio_carb ADD CONSTRAINT galeria_ponto_ensaio_carb_ponto_ensaio_id_fkey
  FOREIGN KEY (ponto_ensaio_id) REFERENCES public.ponto_ensaio_carb(id) ON DELETE CASCADE;

ALTER TABLE public.ponto_ensaio_carb_frentes DROP CONSTRAINT IF EXISTS ponto_ensaio_carb_frentes_ponto_ensaio_id_fkey;
ALTER TABLE public.ponto_ensaio_carb_frentes ADD CONSTRAINT ponto_ensaio_carb_frentes_ponto_ensaio_id_fkey
  FOREIGN KEY (ponto_ensaio_id) REFERENCES public.ponto_ensaio_carb(id) ON DELETE CASCADE;

-- ---------------------------------------------------------------------------
-- 4. Resistividade
-- ---------------------------------------------------------------------------
ALTER TABLE public.ponto_ensaio_resistividade_leitura DROP CONSTRAINT IF EXISTS ponto_ensaio_resistividade_leitura_id_ponto_geral_fkey;
ALTER TABLE public.ponto_ensaio_resistividade_leitura ADD CONSTRAINT ponto_ensaio_resistividade_leitura_id_ponto_geral_fkey
  FOREIGN KEY (id_ponto_geral) REFERENCES public.pontos_ensaios_geral(id) ON DELETE CASCADE;

ALTER TABLE public.galeria_ponto_ensaio_resistividade DROP CONSTRAINT IF EXISTS galeria_ponto_ensaio_resistividade_ponto_ensaio_id_fkey;
ALTER TABLE public.galeria_ponto_ensaio_resistividade ADD CONSTRAINT galeria_ponto_ensaio_resistividade_ponto_ensaio_id_fkey
  FOREIGN KEY (ponto_ensaio_id) REFERENCES public.pontos_ensaios_geral(id) ON DELETE CASCADE;

-- ---------------------------------------------------------------------------
-- 5. Arrancamento (argamassa e cerâmica compartilham estas tabelas)
-- ---------------------------------------------------------------------------
ALTER TABLE public.ponto_ensaio_arrancamento DROP CONSTRAINT IF EXISTS "Ponto_ensaio_arrancamento_ponto_ensaio_id_fkey";
ALTER TABLE public.ponto_ensaio_arrancamento ADD CONSTRAINT "Ponto_ensaio_arrancamento_ponto_ensaio_id_fkey"
  FOREIGN KEY (ponto_ensaio_id) REFERENCES public.pontos_ensaios_geral(id) ON DELETE CASCADE;

ALTER TABLE public.ponto_ensaio_arrancamento_leitura DROP CONSTRAINT IF EXISTS ponto_ensaio_arrancamento_leitura_id_ponto_arrancamento_fkey;
ALTER TABLE public.ponto_ensaio_arrancamento_leitura ADD CONSTRAINT ponto_ensaio_arrancamento_leitura_id_ponto_arrancamento_fkey
  FOREIGN KEY (id_ponto_arrancamento) REFERENCES public.ponto_ensaio_arrancamento(id) ON DELETE CASCADE;

ALTER TABLE public.ponto_ensaio_arrancamento_ruptura DROP CONSTRAINT IF EXISTS ponto_ensaio_arrancamento_ruptura_id_ponto_leitura_fkey;
ALTER TABLE public.ponto_ensaio_arrancamento_ruptura ADD CONSTRAINT ponto_ensaio_arrancamento_ruptura_id_ponto_leitura_fkey
  FOREIGN KEY (id_ponto_leitura) REFERENCES public.ponto_ensaio_arrancamento_leitura(id) ON DELETE CASCADE;

-- ---------------------------------------------------------------------------
-- 6. Potencial de corrosão
-- ---------------------------------------------------------------------------
ALTER TABLE public.ponto_ensaio_potencial DROP CONSTRAINT IF EXISTS ponto_ensaio_potencial_ponto_ensaio_id_fkey;
ALTER TABLE public.ponto_ensaio_potencial ADD CONSTRAINT ponto_ensaio_potencial_ponto_ensaio_id_fkey
  FOREIGN KEY (ponto_ensaio_id) REFERENCES public.pontos_ensaios_geral(id) ON DELETE CASCADE;

ALTER TABLE public.ponto_ensaio_potencial_leitura DROP CONSTRAINT IF EXISTS ponto_ensaio_potencial_leitura_ponto_potencial_id_fkey;
ALTER TABLE public.ponto_ensaio_potencial_leitura ADD CONSTRAINT ponto_ensaio_potencial_leitura_ponto_potencial_id_fkey
  FOREIGN KEY (ponto_potencial_id) REFERENCES public.ponto_ensaio_potencial(id) ON DELETE CASCADE;

-- Referência cruzada com a leitura de resistividade correlata (não é posse) -> zera em vez de travar/apagar.
ALTER TABLE public.ponto_ensaio_potencial_leitura DROP CONSTRAINT IF EXISTS ponto_ensaio_potencial_leitura_id_leitura_resistividade_fkey;
ALTER TABLE public.ponto_ensaio_potencial_leitura ADD CONSTRAINT ponto_ensaio_potencial_leitura_id_leitura_resistividade_fkey
  FOREIGN KEY (id_leitura_resistividade) REFERENCES public.ponto_ensaio_resistividade_leitura(id) ON DELETE SET NULL;

-- ---------------------------------------------------------------------------
-- 7. Inspeção visual
-- ---------------------------------------------------------------------------
ALTER TABLE public.ponto_inspecao_visual_geral DROP CONSTRAINT IF EXISTS ponto_inspecao_visual_geral_id_ponto_geral_fkey;
ALTER TABLE public.ponto_inspecao_visual_geral ADD CONSTRAINT ponto_inspecao_visual_geral_id_ponto_geral_fkey
  FOREIGN KEY (id_ponto_geral) REFERENCES public.pontos_ensaios_geral(id) ON DELETE CASCADE;

ALTER TABLE public.ponto_inspecao_visual DROP CONSTRAINT IF EXISTS ponto_inspecao_visual_id_ponto_geral_fkey;
ALTER TABLE public.ponto_inspecao_visual ADD CONSTRAINT ponto_inspecao_visual_id_ponto_geral_fkey
  FOREIGN KEY (id_ponto_geral) REFERENCES public.ponto_inspecao_visual_geral(id) ON DELETE CASCADE;

ALTER TABLE public.ponto_inspecao_visual DROP CONSTRAINT IF EXISTS ponto_inspecao_visual_id_projeto_fkey;
ALTER TABLE public.ponto_inspecao_visual ADD CONSTRAINT ponto_inspecao_visual_id_projeto_fkey
  FOREIGN KEY (id_projeto) REFERENCES public.projetos(id) ON DELETE CASCADE;

ALTER TABLE public.ponto_inspecao_visual DROP CONSTRAINT IF EXISTS ponto_inspecao_visual_id_estrutura_fkey;
ALTER TABLE public.ponto_inspecao_visual ADD CONSTRAINT ponto_inspecao_visual_id_estrutura_fkey
  FOREIGN KEY (id_estrutura) REFERENCES public.estruturas(id) ON DELETE CASCADE;

-- Referência secundária ao elemento (a posse principal já vem da cadeia id_ponto_geral acima) -> zera.
ALTER TABLE public.ponto_inspecao_visual DROP CONSTRAINT IF EXISTS ponto_inspecao_visual_id_elemento_fkey;
ALTER TABLE public.ponto_inspecao_visual ADD CONSTRAINT ponto_inspecao_visual_id_elemento_fkey
  FOREIGN KEY (id_elemento) REFERENCES public.elementos_estruturais(id) ON DELETE SET NULL;

ALTER TABLE public.ponto_inspecao_visual_anomalia DROP CONSTRAINT IF EXISTS ponto_inspecao_visual_anomalia_id_inspecao_fkey;
ALTER TABLE public.ponto_inspecao_visual_anomalia ADD CONSTRAINT ponto_inspecao_visual_anomalia_id_inspecao_fkey
  FOREIGN KEY (id_inspecao) REFERENCES public.ponto_inspecao_visual(id) ON DELETE CASCADE;

ALTER TABLE public.ponto_inspecao_visual_galeria DROP CONSTRAINT IF EXISTS ponto_inspecao_visual_galeria_id_inspecao_fkey;
ALTER TABLE public.ponto_inspecao_visual_galeria ADD CONSTRAINT ponto_inspecao_visual_galeria_id_inspecao_fkey
  FOREIGN KEY (id_inspecao) REFERENCES public.ponto_inspecao_visual(id) ON DELETE CASCADE;

ALTER TABLE public.ponto_inspecao_regiao DROP CONSTRAINT IF EXISTS ponto_inspecao_regiao_planta_id_fkey;
ALTER TABLE public.ponto_inspecao_regiao ADD CONSTRAINT ponto_inspecao_regiao_planta_id_fkey
  FOREIGN KEY (planta_id) REFERENCES public.estruturas_plantas(id) ON DELETE CASCADE;

ALTER TABLE public.ponto_inspecao_regiao DROP CONSTRAINT IF EXISTS ponto_inspecao_regiao_ponto_id_fkey;
ALTER TABLE public.ponto_inspecao_regiao ADD CONSTRAINT ponto_inspecao_regiao_ponto_id_fkey
  FOREIGN KEY (ponto_id) REFERENCES public.ponto_inspecao_visual(id) ON DELETE CASCADE;

-- ---------------------------------------------------------------------------
-- 8. Esclerometria
-- ---------------------------------------------------------------------------
ALTER TABLE public.ponto_ensaio_esclerometria DROP CONSTRAINT IF EXISTS pontos_ensaios_esclerometria_ponto_geral_id_fkey;
ALTER TABLE public.ponto_ensaio_esclerometria ADD CONSTRAINT pontos_ensaios_esclerometria_ponto_geral_id_fkey
  FOREIGN KEY (ponto_geral_id) REFERENCES public.pontos_ensaios_geral(id) ON DELETE CASCADE;

ALTER TABLE public.ponto_ensaio_esclerometria_leituras DROP CONSTRAINT IF EXISTS ponto_ensaio_esclerom_leituras_ponto_id_fkey;
ALTER TABLE public.ponto_ensaio_esclerometria_leituras ADD CONSTRAINT ponto_ensaio_esclerom_leituras_ponto_id_fkey
  FOREIGN KEY (ponto_id) REFERENCES public.ponto_ensaio_esclerometria(id) ON DELETE CASCADE;

-- ---------------------------------------------------------------------------
-- 9. Prova de carga estática
-- ---------------------------------------------------------------------------
ALTER TABLE public.ponto_ensaio_prova_carga DROP CONSTRAINT IF EXISTS ponto_ensaio_prova_carga_ponto_geral_id_fkey;
ALTER TABLE public.ponto_ensaio_prova_carga ADD CONSTRAINT ponto_ensaio_prova_carga_ponto_geral_id_fkey
  FOREIGN KEY (ponto_geral_id) REFERENCES public.pontos_ensaios_geral(id) ON DELETE CASCADE;

-- Referência secundária ao elemento (a posse principal já vem de ponto_geral_id) -> zera.
ALTER TABLE public.ponto_ensaio_prova_carga DROP CONSTRAINT IF EXISTS ponto_ensaio_prova_carga_elemento_id_fkey;
ALTER TABLE public.ponto_ensaio_prova_carga ADD CONSTRAINT ponto_ensaio_prova_carga_elemento_id_fkey
  FOREIGN KEY (elemento_id) REFERENCES public.elementos_estruturais(id) ON DELETE SET NULL;

ALTER TABLE public.ponto_ensaio_prova_carga_ponto_medicao DROP CONSTRAINT IF EXISTS ponto_ensaio_prova_carga_ponto_medicao_ponto_carga_id_fkey;
ALTER TABLE public.ponto_ensaio_prova_carga_ponto_medicao ADD CONSTRAINT ponto_ensaio_prova_carga_ponto_medicao_ponto_carga_id_fkey
  FOREIGN KEY (ponto_carga_id) REFERENCES public.ponto_ensaio_prova_carga(id) ON DELETE CASCADE;

ALTER TABLE public.ponto_ensaio_prova_carga_ponto_leitura DROP CONSTRAINT IF EXISTS ponto_ensaio_prova_carga_ponto_leitura_ponto_medicao_id_fkey;
ALTER TABLE public.ponto_ensaio_prova_carga_ponto_leitura ADD CONSTRAINT ponto_ensaio_prova_carga_ponto_leitura_ponto_medicao_id_fkey
  FOREIGN KEY (ponto_medicao_id) REFERENCES public.ponto_ensaio_prova_carga_ponto_medicao(id) ON DELETE CASCADE;

-- ---------------------------------------------------------------------------
-- 10. Ultrassom (schema já existe, tela ainda não construída -- deixando pronto)
-- ---------------------------------------------------------------------------
ALTER TABLE public.ponto_ensaio_ultrassom DROP CONSTRAINT IF EXISTS ponto_ensaio_ultrassom_ponto_ensaio_id_fkey;
ALTER TABLE public.ponto_ensaio_ultrassom ADD CONSTRAINT ponto_ensaio_ultrassom_ponto_ensaio_id_fkey
  FOREIGN KEY (ponto_ensaio_id) REFERENCES public.pontos_ensaios_geral(id) ON DELETE CASCADE;

ALTER TABLE public.ponto_ensaio_ultrassom_direto_medicao DROP CONSTRAINT IF EXISTS ponto_ensaio_ultrassom_direto_medicao_ponto_id_fkey;
ALTER TABLE public.ponto_ensaio_ultrassom_direto_medicao ADD CONSTRAINT ponto_ensaio_ultrassom_direto_medicao_ponto_id_fkey
  FOREIGN KEY (ponto_id) REFERENCES public.ponto_ensaio_ultrassom(id) ON DELETE CASCADE;

ALTER TABLE public.ponto_ensaio_ultrassom_direto_leitura DROP CONSTRAINT IF EXISTS ponto_ensaio_ultrassom_direto_leitura_ponto_id_fkey;
ALTER TABLE public.ponto_ensaio_ultrassom_direto_leitura ADD CONSTRAINT ponto_ensaio_ultrassom_direto_leitura_ponto_id_fkey
  FOREIGN KEY (ponto_id) REFERENCES public.ponto_ensaio_ultrassom_direto_medicao(id) ON DELETE CASCADE;

ALTER TABLE public.ponto_ensaio_ultrassom_indireto_medicao DROP CONSTRAINT IF EXISTS ponto_ensaio_ultrassom_indireto_medicao_ponto_id_fkey;
ALTER TABLE public.ponto_ensaio_ultrassom_indireto_medicao ADD CONSTRAINT ponto_ensaio_ultrassom_indireto_medicao_ponto_id_fkey
  FOREIGN KEY (ponto_id) REFERENCES public.ponto_ensaio_ultrassom(id) ON DELETE CASCADE;

ALTER TABLE public.ponto_ensaio_ultrassom_indireto_leitura DROP CONSTRAINT IF EXISTS ponto_ensaio_ultrassom_indireto_leitura_ponto_id_fkey;
ALTER TABLE public.ponto_ensaio_ultrassom_indireto_leitura ADD CONSTRAINT ponto_ensaio_ultrassom_indireto_leitura_ponto_id_fkey
  FOREIGN KEY (ponto_id) REFERENCES public.ponto_ensaio_ultrassom_indireto_medicao(id) ON DELETE CASCADE;

-- ---------------------------------------------------------------------------
-- 11. Projeto -> Estrutura (vínculo N:N) e demais tabelas presas ao projeto
--
-- Importante: cascade nas DUAS pontas do vínculo projeto_estruturas é sobre
-- a linha de VÍNCULO em si, não sobre a Estrutura. Excluir um Projeto NUNCA
-- apaga a Estrutura automaticamente (isso é feito por uma chamada separada e
-- explícita no app, só quando o usuário confirmar). Excluir uma Estrutura
-- some com os vínculos dela em qualquer projeto (senão o delete da estrutura
-- falharia por violação de FK vindo desta tabela).
-- ---------------------------------------------------------------------------
ALTER TABLE public.projeto_estruturas DROP CONSTRAINT IF EXISTS projeto_estruturas_projeto_id_fkey;
ALTER TABLE public.projeto_estruturas ADD CONSTRAINT projeto_estruturas_projeto_id_fkey
  FOREIGN KEY (projeto_id) REFERENCES public.projetos(id) ON DELETE CASCADE;

ALTER TABLE public.projeto_estruturas DROP CONSTRAINT IF EXISTS projeto_estruturas_estrutura_id_fkey;
ALTER TABLE public.projeto_estruturas ADD CONSTRAINT projeto_estruturas_estrutura_id_fkey
  FOREIGN KEY (estrutura_id) REFERENCES public.estruturas(id) ON DELETE CASCADE;

ALTER TABLE public.projeto_equipe_interna DROP CONSTRAINT IF EXISTS projeto_equipe_interna_projeto_id_fkey;
ALTER TABLE public.projeto_equipe_interna ADD CONSTRAINT projeto_equipe_interna_projeto_id_fkey
  FOREIGN KEY (projeto_id) REFERENCES public.projetos(id) ON DELETE CASCADE;

ALTER TABLE public.projeto_convites_cliente DROP CONSTRAINT IF EXISTS projeto_convites_cliente_projeto_id_fkey;
ALTER TABLE public.projeto_convites_cliente ADD CONSTRAINT projeto_convites_cliente_projeto_id_fkey
  FOREIGN KEY (projeto_id) REFERENCES public.projetos(id) ON DELETE CASCADE;

ALTER TABLE public.projeto_empresas_colaboradoras DROP CONSTRAINT IF EXISTS projeto_empresas_colaboradoras_projeto_id_fkey;
ALTER TABLE public.projeto_empresas_colaboradoras ADD CONSTRAINT projeto_empresas_colaboradoras_projeto_id_fkey
  FOREIGN KEY (projeto_id) REFERENCES public.projetos(id) ON DELETE CASCADE;

ALTER TABLE public.relatorios DROP CONSTRAINT IF EXISTS relatorios_projeto_id_fkey;
ALTER TABLE public.relatorios ADD CONSTRAINT relatorios_projeto_id_fkey
  FOREIGN KEY (projeto_id) REFERENCES public.projetos(id) ON DELETE CASCADE;

ALTER TABLE public.relatorio_ensaio DROP CONSTRAINT IF EXISTS relatorio_ensaio_projeto_id_fkey;
ALTER TABLE public.relatorio_ensaio ADD CONSTRAINT relatorio_ensaio_projeto_id_fkey
  FOREIGN KEY (projeto_id) REFERENCES public.projetos(id) ON DELETE CASCADE;

-- ============================================================================
-- Fim. Depois de rodar, teste criando um elemento com pelo menos 2 tipos de
-- ensaio, salvando dados neles, e excluindo o elemento pelo app -- confirme
-- que as tabelas de ensaio ficaram vazias (SELECT) e nenhum erro de FK apareceu.
-- ============================================================================
