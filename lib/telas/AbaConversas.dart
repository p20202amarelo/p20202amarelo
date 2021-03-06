// Cabeçalho:
//  Este módulo é responsavel por definir a aba de conversas não arquivadas e suas funcionalidades
//  1.Para implementar a funcionalidade de arquivar conversas,
//  1.1.Foi criado um botão em cada opção de conversa. Quando clicado, ele chama o método _arquivarConversa.
//  1.2.Foi também colocado uma booleana, no objeto Conversa, colocado no Firestore. Que indica se a conversa está arquivada

import 'dart:async';
import 'package:flutter/material.dart';
import '../model/Conversa.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../model/Usuario.dart';

class AbaConversas extends StatefulWidget {
  @override
  _AbaConversasState createState() => _AbaConversasState();
}

class _AbaConversasState extends State<AbaConversas> {

  List<Conversa> _listaConversas = [];
  final _controller = StreamController<QuerySnapshot>.broadcast();
  Firestore db = Firestore.instance;
  String _idUsuarioLogado;

  @override
  void initState() {
    super.initState();
    _recuperarDadosUsuario();

    Conversa conversa = Conversa();
    conversa.nome = "Ana Clara";
    conversa.mensagem = "Olá tudo bem?";
    conversa.caminhoFoto = "https://firebasestorage.googleapis.com/v0/b/whatsapp-36cd8.appspot.com/o/perfil%2Fperfil1.jpg?alt=media&token=97a6dbed-2ede-4d14-909f-9fe95df60e30";

    _listaConversas.add(conversa);

  }

  Stream<QuerySnapshot> _adicionarListenerConversas(){

    final stream = db.collection("conversas")
        .document( _idUsuarioLogado )
        .collection("ultima_conversa")
        .where('arquivada', isEqualTo: false) //abv
        .snapshots();

    stream.listen((dados){
      _controller.add( dados );
    });

    return stream; // warning clearer

  }

  _arquivarConversa(String idDestinatario) async {
    Firestore db = Firestore.instance;
    await db.collection("conversas")
        .document( _idUsuarioLogado )
        .collection( "ultima_conversa" )
        .document( idDestinatario )
        .updateData({"arquivada" : true});
  }

  _recuperarDadosUsuario() async {

    FirebaseAuth auth = FirebaseAuth.instance;
    FirebaseUser usuarioLogado = await auth.currentUser();
    setState(() {
      _idUsuarioLogado = usuarioLogado.uid;
    });

    _adicionarListenerConversas();


  }

  @override
  void dispose() {
    super.dispose();
    _controller.close();
  }

  @override
  Widget build(BuildContext context) {

    return StreamBuilder<QuerySnapshot>(
      stream: _controller.stream,
      builder: (context, snapshot){
        switch (snapshot.connectionState) {
          case ConnectionState.none:
          case ConnectionState.waiting:
          return Center(
            child: Column(
              children: <Widget>[
                Text("Carregando conversas"),
                CircularProgressIndicator()
              ],
            ),
          );
          break;
          case ConnectionState.active:
          case ConnectionState.done:
            if (snapshot.hasError) {
              return Text("Erro ao carregar os dados!");
            }else{

              QuerySnapshot querySnapshot = snapshot.data;

              if( querySnapshot.documents.length == 0 ){ // LEK
                return Center(
                  child: Text(
                    "Você não tem nenhuma conversa ainda, ou todas as suas conversas estão arquivadas " + querySnapshot.documents.length.toString(),
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold
                    ),
                  ),
                );
              }

              return ListView.builder(
                  itemCount: querySnapshot.documents.length, //_listaConversas.length,
                  itemBuilder: (context, indice){

                    List<DocumentSnapshot> conversas = querySnapshot.documents.toList();
                    DocumentSnapshot item = conversas[indice];

                    String urlImagem  = item["caminhoFoto"];
                    String tipo       = item["tipoMensagem"];
                    String mensagem   = item["mensagem"];
                    String nome       = item["nome"];
                    print("ind="+indice.toString()+ " nome="+nome);
                    String idDestinatario       = item["idDestinatario"];

                    Usuario usuario = Usuario();
                    usuario.nome = nome;
                    usuario.urlImagem = urlImagem;
                    usuario.idUsuario = idDestinatario;

                    return ListTile(
                      onTap: (){
                        Navigator.pushNamed(
                            context,
                            "/mensagens",
                            arguments: usuario
                        );
                      },
                      contentPadding: EdgeInsets.fromLTRB(16, 8, 16, 8),
                      leading: CircleAvatar(
                        maxRadius: 30,
                        backgroundColor: Colors.grey,
                        backgroundImage: urlImagem!=null
                            ? NetworkImage( urlImagem )
                            : null,
                      ),
                      title: Text(
                        nome,
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16
                        ),
                      ),
                      subtitle: Text(
                          tipo=="texto"
                              ? mensagem
                              : "Imagem...",
                          style: TextStyle(
                              color: Colors.grey,
                              fontSize: 14
                          )
                      ),
                      trailing: IconButton(
                              icon: const Icon(Icons.archive_outlined),
                              tooltip: "Arquivar Conversa",
                              onPressed: () {
                                _arquivarConversa(usuario.idUsuario);
                              }, //abv
                      ),
                    );

                  }
              );

            }
        }
      },
    );


  }
}
