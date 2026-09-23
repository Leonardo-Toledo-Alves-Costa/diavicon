-- NÃO APLICADA: os valores de produção (21/09/2026) foram mantidos por decisão do Francisco.
-- Catálogo de planos: Freemium, Básico, Avançado e Empresarial.
--
-- Atualiza a linha se já existir um plano com o mesmo nome (sem diferenciar
-- maiúsculas) e cria se não existir. NÃO apaga nem altera planos com outros
-- nomes: se ainda houver planos antigos (Starter, Basic, Professional...),
-- migre as empresas e remova-os à mão depois de conferir.
--
-- Avançado e Empresarial incluem tudo do Básico. "offline" fica marcado no
-- Básico em diante, mas o app ainda não oferece modo offline e não mostra esse
-- item na lista de recursos.
--
-- Pode rodar mais de uma vez sem erro.

begin;

do $do$
declare
  r record;
begin
  for r in
    select * from (values
      --  nome          descricao                                                                                              valor    mb     users ads    offline servicos feed   rdo    dash   relat  monitor tokens_estr
      ('Freemium',    'Plano gratuito com anúncios.',                                                                          0.00,    250,   5,    true,  false,  false,   false, false, false, false, false,  0),
      ('Básico',      'Plano iniciante com funções básicas.',                                                                  129.90,  5120,  10,   false, true,   true,    true,  false, false, false, false,  0),
      ('Avançado',    'Plano para empresas experientes, com maior capacidade e desempenho.',                                   249.90,  15360, 15,   false, true,   true,    true,  true,  true,  true,  true,   10),
      ('Empresarial', 'Plano para empresas gestoras e de engenharia diagnóstica, completo para o campo e para o escritório.', 379.90,  30720, 20,   false, true,   true,    true,  true,  true,  true,  true,   20)
    ) as v(nome, descricao, valor, mb, users, ads, offline, servicos, feed, rdo, dash, relat, monitor, tokens_estr)
  loop
    update public.planos p set
      descricao = r.descricao,
      valor = r.valor,
      armazenamento_mb = r.mb,
      qtd_user = r.users,
      ads = r.ads,
      offline = r.offline,
      servicos = r.servicos,
      publicar_feed_edu = r.feed,
      rdo_gastos = r.rdo,
      dashboard = r.dash,
      gerar_relatorio = r.relat,
      monitor = r.monitor,
      tokens_estrutura = r.tokens_estr
    where lower(btrim(p.nome)) = lower(r.nome);

    if not found then
      insert into public.planos (nome, descricao, valor, vigencia_dias, armazenamento_mb, qtd_user, ads, offline,
                                 servicos, publicar_feed_edu, rdo_gastos, dashboard, gerar_relatorio, monitor, tokens_estrutura)
      values (r.nome, r.descricao, r.valor, 30, r.mb, r.users, r.ads, r.offline,
              r.servicos, r.feed, r.rdo, r.dash, r.relat, r.monitor, r.tokens_estr);
    end if;
  end loop;
end;
$do$;

commit;
