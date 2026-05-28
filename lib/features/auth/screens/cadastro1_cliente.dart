import 'package:diavicon/core/constants/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class Cadastro1Cliente extends StatefulWidget {
  final Map<String, dynamic> dadosUsuario;

  const Cadastro1Cliente({super.key, required this.dadosUsuario});

  @override
  State<Cadastro1Cliente> createState() => _Cadastro1ClienteState();
}

class _Cadastro1ClienteState extends State<Cadastro1Cliente> {
  // Lista de serviços para o Checkbox
  final List<String> _servicos = [
    
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
                height: 80,
                alignment: Alignment.centerLeft,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(9),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                child: const Text(
                  'Qual tipo de ativo você deseja \nmonitorar?',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                  textAlign: TextAlign.left,
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
                    itemCount: _servicos.length,
                    padding: const EdgeInsets.all(8),
                    itemBuilder: (context, index) {
                      return CheckboxListTile(
                        title: Text(_servicos[index]),
                        value: _selecionados[index],
                        activeColor: AppColors.primary,
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
                    child: const Text('<   Voltar', style: TextStyle(color: AppColors.primary, fontSize: 16)),
                  ),
                  const Spacer(),
                  SizedBox(
                    height: 44,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      // Passando o extra adiante para a Cadastro3
                      onPressed: () {
                        // Adicionar os serviços selecionados ao mapa antes de enviar
                        final servicosFinal = [];
                        for (var i = 0; i < _selecionados.length; i++) {
                          if (_selecionados[i]) servicosFinal.add(_servicos[i]);
                        }
                        
                        final dadosAtualizados = {
                          ...widget.dadosUsuario,
                          'servicos': servicosFinal,
                        };

                        context.push('/register/cliente/planos', extra: dadosAtualizados);
                      },
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