import 'package:diavicon/core/constants/app_colors.dart';
import 'package:diavicon/core/widgets/auth_layout.dart';
import 'package:diavicon/core/widgets/compact_button.dart';
import 'package:diavicon/core/widgets/custom_button.dart';
import 'package:diavicon/core/widgets/custom_text_button.dart';
import 'package:diavicon/core/widgets/custom_text_field.dart';
import 'package:flutter/material.dart';

class Cadastro0Empresa extends StatelessWidget {
  const Cadastro0Empresa({super.key});

  @override
  Widget build(BuildContext context) {
    final screenwidth = MediaQuery.of(context).size.width;
    final screenheight = MediaQuery.of(context).size.height;
    return AuthLayout(
      child: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Wrap(
                children: [
                  Text(
                    'Sua empresa já é cadastrada na ',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'DIAVICON',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  Text(
                    '?',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              SizedBox(height: screenheight * 0.08),
              SizedBox(
                width: screenwidth * 0.8,
                child: FilledButton(
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.all(AppColors.primary),
                    foregroundColor: WidgetStateProperty.all(Colors.white),
                    shape: WidgetStateProperty.all(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    padding: WidgetStateProperty.all(
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    ),
                  ),
                  onPressed: () {},
                  child: Row(
                    mainAxisSize: MainAxisSize.max,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(Icons.apartment, size: 55),
                      SizedBox(width: 15),
                      Expanded(
                        child: Text(
                          'Quero cadastrar minha empresa',
                          maxLines: 2,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: screenheight * 0.04),
              Container(
                width: screenwidth * 0.8,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(10),
                  shape: BoxShape.rectangle,
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.max,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Sou membro de uma empresa',
                      textAlign: TextAlign.start,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 15),
                    Text(
                      'Entre com o código de acesso enviado por sua empresa',
                      textAlign: TextAlign.start,
                      maxLines: 2,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w300,
                        color: Colors.white
                      ),
                    ),
                    SizedBox(height: 15),
                    TextField(
                      controller: TextEditingController(),
                      style: TextStyle(fontSize: 12),
                      decoration: InputDecoration(
                        hintStyle: TextStyle(
                          color: AppColors.hintText,
                          fontSize: 12,
                        ),
                        hintText: 'AbCD123',
                        isDense: true,
                        filled: true,
                        fillColor: AppColors.background,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: AppColors.background),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: AppColors.background),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: AppColors.background),
                        ),
                      ),
                    )
                  ],
                ),
              ),
              SizedBox(height: screenheight * 0.1),
              CustomTextbutton(
                text: '<   Voltar',
                onPressed: () {},
              ),
            ],
          ),
        ),
      ),
    );
  }
}
