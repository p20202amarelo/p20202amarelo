// Cabeçalho:
//  Este módulo é responsavel por fazer a troca de telas.

import 'package:flutter/material.dart';
import 'package:p20202amarelo/CriarGrupo.dart';
import 'package:p20202amarelo/MensagensGrupo.dart';
import 'package:p20202amarelo/Recuperacao.dart';
import 'package:p20202amarelo/VerIntegrantes.dart';

import 'Cadastro.dart';
import 'Configuracoes.dart';
import 'Home.dart';
import 'Login.dart';
import 'Mensagens.dart';
import 'PopularGrupo.dart';

class RouteGenerator {

  static Route<dynamic> generateRoute(RouteSettings settings){

    final args = settings.arguments;

    switch( settings.name ){
      case "/" :
        return MaterialPageRoute(
          builder: (_) => Login()
        );
      case "/login" :
        return MaterialPageRoute(
            builder: (_) => Login()
        );
      case "/recuperacao" :
        return MaterialPageRoute(
            builder: (_) => Recuperacao()
        );
      case "/cadastro" :
        return MaterialPageRoute(
            builder: (_) => Cadastro()
        );
      case "/criargrupo" :
        return MaterialPageRoute(
            builder: (_) => CriarGrupo()
        );
      case "/populargrupo" :
        return MaterialPageRoute(
            builder: (_) => PopularGrupo(args)
        );
      case "/verintegrantes" :
        return MaterialPageRoute(
            builder: (_) => VerIntegrantes(args)
        );
      case "/home" :
        return MaterialPageRoute(
            builder: (_) => Home()
        );
      case "/configuracoes" :
        return MaterialPageRoute(
            builder: (_) => Configuracoes()
        );
      case "/mensagens" :
        return MaterialPageRoute(
            builder: (_) => Mensagens(args)
        );
      case "/mensagensgrupo" :
        return MaterialPageRoute(
            builder: (_) => MensagensGrupo(args)
        );
      default:
        _erroRota();
    }

  }

  static Route<dynamic> _erroRota(){
    return MaterialPageRoute(
      builder: (_){
        return Scaffold(
          appBar: AppBar(title: Text("Tela não encontrada!"),),
          body: Center(
            child: Text("Tela não encontrada!"),
          ),
        );
      }
    );
  }

}