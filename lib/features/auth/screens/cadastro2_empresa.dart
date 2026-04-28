import 'package:diavicon/core/constants/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class Cadastro2Empresa extends StatefulWidget {
  const Cadastro2Empresa({super.key});

  @override
  State<Cadastro2Empresa> createState() => _Cadastro2EmpresaState();
}

class _Cadastro2EmpresaState extends State<Cadastro2Empresa> {
  // Lista de serviços para o Checkbox não ficar "vazio"
  final List<String> _servicos = [
    'Vistorias',
    'Laudos Técnicos',
    'Inspeção Predial',
    'Ensaios Tecnológicos',
    'Consultoria',
    'Acompanhamento de Obras'
  ];
  
  late final List<bool> _selecionados = List<bool>.filled(_servicos.length, false);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 20),
          child: Column(
            children: [
              const SizedBox(height: 8),
              Image.asset(
                'assets/images/logo_diavicon.png',
                height: 150,
                fit: BoxFit.contain,
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: 0.68,
                  minHeight: 9,
                  backgroundColor: Colors.grey.shade500,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                height: 60,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(9),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                child: const Text(
                  'Quais serviços que você realiza?',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                    height: 1.1,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: ListView.builder(
                    itemCount: _selecionados.length,
                    padding: const EdgeInsets.fromLTRB(6, 8, 6, 8),
                    itemBuilder: (context, index) {
                      return CheckboxListTile( // Usei ListTile para ter o texto ao lado
                        title: Text(_servicos[index], style: const TextStyle(fontWeight: FontWeight.w500)),
                        value: _selecionados[index],
                        activeColor: AppColors.primary,
                        checkColor: Colors.white,
                        controlAffinity: ListTileControlAffinity.leading,
                        onChanged: (value) {
                          setState(() {
                            _selecionados[index] = value ?? false;
                          });
                        },
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  TextButton(
                    onPressed: () => context.pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                    ),
                    child: const Text('<   Voltar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                  ),
                  const Spacer(),
                  SizedBox(
                    height: 44,
                    child: ElevatedButton(
                      // NAVEGAÇÃO: Vai para a tela de planos
                      onPressed: () => context.push('/empresa/planos'), 
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Avançar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}