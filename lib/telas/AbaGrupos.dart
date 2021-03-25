

import 'package:flutter/material.dart';
import '../model/Conversa.dart';
import '../model/Usuario.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AbaGrupos extends StatefulWidget {
  @override
  _AbaGruposState createState() => _AbaGruposState();
}

class _AbaGruposState extends State<AbaGrupos> {

  String _idUsuarioLogado;
  String _emailUsuarioLogado;

  Future<List<Usuario>> _recuperarContatos() async { // recupera grupos
    Firestore db = Firestore.instance;

    QuerySnapshot querySnapshot =
    await db.collection("grupos").getDocuments();

    List<Usuario> listaUsuarios = [];
    for (DocumentSnapshot item in querySnapshot.documents) {

      QuerySnapshot queryIntegrante = await db.collection("grupos").document(item.documentID).collection("integrantes").getDocuments();
      for (DocumentSnapshot integrante in queryIntegrante.documents){
        if(integrante.documentID==_idUsuarioLogado){
          Usuario usuario = Usuario();
          usuario.idUsuario = item.documentID;
          listaUsuarios.add(usuario);
          break;
        }
      }
    }

    return listaUsuarios;
  }

  _recuperarDadosUsuario() async {

    FirebaseAuth auth = FirebaseAuth.instance;
    FirebaseUser usuarioLogado = await auth.currentUser();
    _idUsuarioLogado = usuarioLogado.uid;
    _emailUsuarioLogado = usuarioLogado.email;

  }

  @override
  void initState() {
    super.initState();
    _recuperarDadosUsuario();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Usuario>>(
      future: _recuperarContatos(),
      builder: (context, snapshot) {
        switch (snapshot.connectionState) {
          case ConnectionState.none:
          case ConnectionState.waiting:
            return Center(
              child: Column(
                children: <Widget>[
                  Text("Carregando contatos"),
                  CircularProgressIndicator()
                ],
              ),
            );
            break;
          case ConnectionState.active:
          case ConnectionState.done:
            return ListView.builder(
                itemCount: snapshot.data.length,
                itemBuilder: (_, indice) {

                  List<Usuario> listaItens = snapshot.data;
                  Usuario usuario = listaItens[indice];

                  return ListTile(
                    onTap: (){
                      Navigator.pushNamed(
                          context,
                          "/mensagensgrupo",
                          arguments: usuario.idUsuario
                      );
                    },
                    contentPadding: EdgeInsets.fromLTRB(16, 8, 16, 8),
                    leading: CircleAvatar(
                        maxRadius: 30,
                        backgroundColor: Colors.grey,
                        backgroundImage: usuario.urlImagem != null
                            ? NetworkImage(usuario.urlImagem)
                            : null),
                    title: Text(
                      usuario.idUsuario,
                      style:
                      TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  );
                });
            break;
        }
      },
    );
  }
}
