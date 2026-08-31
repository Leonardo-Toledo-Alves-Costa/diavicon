import 'package:flutter/material.dart';

class AnaliseCarbonatacaoModel {
  //informações elemento
  final String elementoNome;
  final String tipoElemento;
  //final String tipologiaEstruturalElemento;
  final String local;
  final String revestimento;
  
  //dados Projeto
  //final String nomeProjeto;

  //dados estrutura
  //final String nomeEstrutura;
  final int idadeAnos;
  final String ambiente;
  final String caa;
  //final String conjuntoEstrutural;
  //final String utilizacaoEstrutura;
  //final String tipoEstrutura;
  //final String tipologiaEstrutural;
 

  final String pontoNome;
  final double? cobArmP;
  final double? bitArmP;
  final double? cobArmS;
  final double? bitArmS;

  final double carbonatacaoMedia;
  final double carbonatacaoMaior;
  final double carbonatacaoMenor;
  final double coefVariacao;

  // Variáveis calculadas da lógica Python
  final double cobrimentoEfetivo;
  final double coefCarb; // k = FrenteCarbon / sqrt(idade)
  final double tempoCarbonatar;
  final double deltaCarb;
  final String condicaoRisco;
  final Color corRisco;
  final double tempoCalc;
  final double tempoAnaliseGrafico;

  final String tipoEnsaio;


  AnaliseCarbonatacaoModel({
    //required this.nomeProjeto,
    //required this.nomeEstrutura,
    //required this.conjuntoEstrutural,
    //required this.utilizacaoEstrutura,
    //required this.tipoEstrutura,
    //required this.tipologiaEstrutural,
    required this.pontoNome,
    required this.elementoNome,
    required this.tipoElemento,
    //required this.tipologiaEstruturalElemento,
    required this.local,
    required this.idadeAnos,
    required this.ambiente,
    required this.caa,
    required this.revestimento,
    this.cobArmP,
    this.bitArmP,
    this.cobArmS,
    this.bitArmS,
    required this.carbonatacaoMedia,
    required this.carbonatacaoMaior,
    required this.carbonatacaoMenor,
    required this.coefVariacao,
    required this.cobrimentoEfetivo,
    required this.coefCarb,
    required this.tempoCarbonatar,
    required this.deltaCarb,
    required this.condicaoRisco,
    required this.corRisco,
    required this.tempoCalc,
    required this.tempoAnaliseGrafico,
    required this.tipoEnsaio,
  });

  bool get isHomogeneo => coefVariacao <= 15;
}