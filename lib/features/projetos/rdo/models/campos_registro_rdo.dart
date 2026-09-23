import 'package:diavicon/features/modelos_relatorios/models/quadro_model.dart';

/// Catálogo dos campos fixos de um "Registro" de RDO — para o mesmo
/// `QuadroEditor`/`QuadroHtmlHelpers` que os ensaios usam (o usuário monta
/// linhas/colunas livremente, só que escolhendo entre estes campos fixos em
/// vez de um catálogo arbitrário, já que as colunas de `rdo_realizado` não
/// mudam). "Turnos" não entra aqui — é um bloco de repetição (subLista, 3
/// itens: manhã/tarde/noite), ver [camposTurnoRdo].
const List<CampoCatalogo> camposRegistroRdo = [
  CampoCatalogo('status_rdo', 'Status', TipoCampoCatalogo.texto),
  CampoCatalogo('data_rdo', 'Data', TipoCampoCatalogo.texto),
  CampoCatalogo('equipe_rdo', 'Equipe', TipoCampoCatalogo.texto),
  CampoCatalogo('atividades_rdo', 'Atividades realizadas', TipoCampoCatalogo.texto),
  CampoCatalogo('equipamentos_rdo', 'Equipamentos utilizados', TipoCampoCatalogo.texto),
  CampoCatalogo('observacoes_rdo', 'Observações', TipoCampoCatalogo.texto),
];

/// Catálogo de um turno — usado como `catalogoSubLista` do slot "Turnos"
/// dentro de Registros. Cada RDO gera até 3 linhas (manhã/tarde/noite).
const List<CampoCatalogo> camposTurnoRdo = [
  CampoCatalogo('periodo_turno', 'Período', TipoCampoCatalogo.texto),
  CampoCatalogo('chegada_turno', 'Chegada', TipoCampoCatalogo.texto),
  CampoCatalogo('inicio_turno', 'Início', TipoCampoCatalogo.texto),
  CampoCatalogo('saida_turno', 'Saída', TipoCampoCatalogo.texto),
  CampoCatalogo('cond_trabalho_turno', 'Condição de trabalho', TipoCampoCatalogo.texto),
  CampoCatalogo('cond_clima_turno', 'Condição climática', TipoCampoCatalogo.texto),
];

const Map<String, String> dadosExemploRegistroRdo = {
  'status_rdo': 'Postado',
  'data_rdo': '22/03/2026',
  'equipe_rdo': 'João Silva, Maria Souza',
  'atividades_rdo': 'Concretagem da laje do 3º pavimento.',
  'equipamentos_rdo': 'Betoneira, vibrador de imersão.',
  'observacoes_rdo': 'Sem intercorrências.',
};

const List<Map<String, String>> dadosExemploTurnosRdo = [
  {
    'periodo_turno': 'Manhã',
    'chegada_turno': '07:30',
    'inicio_turno': '08:00',
    'saida_turno': '12:00',
    'cond_trabalho_turno': 'Praticável',
    'cond_clima_turno': 'Ensolarado',
  },
  {
    'periodo_turno': 'Tarde',
    'chegada_turno': '13:00',
    'inicio_turno': '13:30',
    'saida_turno': '17:30',
    'cond_trabalho_turno': 'Praticável',
    'cond_clima_turno': 'Nublado',
  },
];
