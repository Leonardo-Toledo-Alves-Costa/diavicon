import 'package:flutter/material.dart';
import 'team_edit_item.dart';

class EditTeamBody extends StatefulWidget {
  const EditTeamBody({super.key});

  @override
  State<EditTeamBody> createState() => _EditTeamBodyState();
}

class _EditTeamBodyState extends State<EditTeamBody> {
  // Lista Mock para o front [image_7b8e71.png]
  final List<Map<String, dynamic>> _usuarios = [
    {'nome': 'Fulano Ciclano', 'cargo': 'Engenheiro Diagnóstico', 'sub': 'Diretor CEO', 'selected': true},
    {'nome': 'Fulano Ciclano', 'cargo': 'Engenheiro Diagnóstico', 'sub': 'Diretor CEO', 'selected': false},
    {'nome': 'Fulano Ciclano', 'cargo': 'Engenheiro Diagnóstico', 'sub': 'Diretor CEO', 'selected': false},
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: _usuarios.map((user) {
        return TeamEditItem(
          name: user['nome'],
          role: user['cargo'],
          subRole: user['sub'],
          isSelected: user['selected'],
          onChanged: (val) {
            setState(() => user['selected'] = val);
          },
        );
      }).toList(),
    );
  }
}