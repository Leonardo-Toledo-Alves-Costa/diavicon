import 'package:flutter/material.dart';

// Observer global de navegação — permite que uma tela saiba quando volta a
// ficar visível (`didPopNext`), mesmo que a rota empurrada por cima dela
// tenha sido aberta de forma imperativa (Navigator.push), fora da árvore
// declarativa do go_router. Usado por telas cujos dados podem ter mudado
// numa tela filha (ex: PontosEnsaioScreen, que precisa recarregar a lista
// depois que o usuário cria/edita um ponto de ensaio e volta).
final RouteObserver<PageRoute> appRouteObserver = RouteObserver<PageRoute>();
