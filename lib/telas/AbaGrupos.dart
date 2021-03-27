// Cabeçalho:
//  Este módulo é responsável por mostrar os grupos do qual o usuário logado faz parte.

import 'package:flutter/material.dart';
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


  Future<List<Usuario>> _recuperarGrupos() async { // recupera grupos
    Firestore db = Firestore.instance;

    QuerySnapshot querySnapshot =
    await db.collection("grupos").getDocuments();

    List<Usuario> listaUsuarios = [];
    for (DocumentSnapshot item in querySnapshot.documents) {

      QuerySnapshot queryIntegrante = await db.collection("grupos")
          .document(item.documentID)
          .collection("integrantes")
          .getDocuments();

      for (DocumentSnapshot integrante in queryIntegrante.documents){
        if(integrante.documentID==_idUsuarioLogado){
          Usuario usuario = Usuario();
          usuario.idUsuario = item.documentID;
          usuario.nome = item.data["nome"];
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

  _checaSeVazio(String grupoId) async{
    QuerySnapshot qs = await Firestore.instance
        .collection("grupos")
        .document(grupoId)
        .collection("integrantes").getDocuments();

    if(qs.documents.length == 0){


      CollectionReference qsi = await Firestore.instance.collection("grupos").document(grupoId).collection("mensagens");

      Firestore.instance.collection("grupos").document(grupoId).delete();

      batchDelete(qsi);

    }
  }

  Future<void> batchDelete(CollectionReference cr) {
    WriteBatch batch = Firestore.instance.batch();

    return cr.getDocuments().then((querySnapshot) {
      querySnapshot.documents.forEach((document) {
        batch.delete(document.reference);
      });
      setState(() {

      });
      return batch.commit();
    });

  }

  Widget _buildPopupDialog(BuildContext context, String grupoId) {
    return AlertDialog(
      title:Text("Opções:"),
      actions: <Widget>[
        TextButton(
          child:Text("Ver Integrantes"),
          onPressed: (){
            Navigator.pushReplacementNamed(context, '/verintegrantes', arguments: grupoId);
          },
        ),
        TextButton(
          child:Text("Retirar-se do grupo"),
          onPressed: (){
            Firestore.instance
                .collection("grupos")
                .document(grupoId)
                .collection("integrantes")
                .document(_idUsuarioLogado)
                .delete();

            _checaSeVazio(grupoId);

            Navigator.of(context).pop();
          },
        )
      ],
    );
  }

  @override
  void initState() {
    super.initState();
    _recuperarDadosUsuario();
    _recuperarGrupos();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Usuario>>(
      future: _recuperarGrupos(),
      builder: (context, snapshot) {
        switch (snapshot.connectionState) {
          case ConnectionState.none:
          case ConnectionState.waiting:
            return Center(
              child: Column(
                children: <Widget>[
                  Text("Carregando grupos"),
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

                  return InkWell(
                    onLongPress:(){
                      showDialog(context: context,
                          builder: (BuildContext context) => _buildPopupDialog(context, usuario.idUsuario));
                    },
                    child: ListTile(
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
                        usuario.nome,
                        style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    )
                  );


                });
            break;
        }
      },
    );
  }
}
