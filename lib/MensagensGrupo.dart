// Cabeçalho:
//  Este módulo é responsável por definir a tela de conversa e todas suas funcionalidades.
//  1.Para implementar a notificação. Quando o botão de enviar é apertado, o osId é recuperado pelo Firestore, e uma notificação é postada para o osId do destinatário.
//  1.1.Isto funciona tanto para uma mensagem de texto, quanto uma foto.
//  2.Para implementar a remoção de mensagens foram criados os métodos _removerMensagem e _buildPopupDialog.
//  2.1 O _buildPopupDialog abre uma janela quando a mensagem é pressionado por um tempo, apresentando duas opções para o usuário e então chama _removerMensagem.
//  2.2 O _removerMensagem acessa o Firebase e procura a mensagem a ser removida pelo seu timestamp, em seguida trocando o texto da mensagem para "[Mensagem apagada]"

import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'model/Conversa.dart';
import 'model/Mensagem.dart';
import 'model/Usuario.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

class MensagensGrupo extends StatefulWidget {
  String grupoNome;

  MensagensGrupo(this.grupoNome);

  @override
  _MensagensGrupoState createState() => _MensagensGrupoState();
}



class _MensagensGrupoState extends State<MensagensGrupo> {
  File _imagem;
  bool _subindoImagem = false;
  String _idUsuarioLogado;
  String _idGrupoNome;
  String _urlImagemRemetente="blz2"; // Remetente eh o logado
  String _nomeRemetente="blz2";
  static ImagePicker _imagePicker = null;

  Firestore db = Firestore.instance;
  TextEditingController _controllerMensagem = TextEditingController();

  final _controller = StreamController<QuerySnapshot>.broadcast();
  ScrollController _scrollController = ScrollController();


  _MensagensState(){
    if (_imagePicker == null)
      _imagePicker = ImagePicker();
  }

  _enviarMensagem() {
    String textoMensagem = _controllerMensagem.text;
    if (textoMensagem.isNotEmpty) {
      Mensagem mensagem = Mensagem();
      mensagem.idUsuario = _idUsuarioLogado;
      mensagem.mensagem = textoMensagem;
      mensagem.timeStamp = Timestamp.now(); //LEK
      mensagem.urlImagem = "";
      mensagem.tipo = "texto";

      //Salvar mensagem para remetente
      _salvarMensagem(_idUsuarioLogado, _idGrupoNome, mensagem);

      //abv
      _postarnotif(mensagem);

    }
  }

  _postarnotif(Mensagem mensagem) async {
    var status = await OneSignal.shared.getPermissionSubscriptionState();

    var playerId = await _recuperarOsIdDestino();//status.subscriptionStatus.userId;

    var response;

    if(mensagem.urlImagem != ""){
      response = await OneSignal.shared.postNotificationWithJson({
        "include_player_ids" : [ playerId],
        "contents" : {"en" : "abra o app para ver a imagem "}, // se não tiver isso a notificação não funfa
        "headings" : {"en" : "Você recebeu uma imagem!"},
      });
    }
    else{
      response = await OneSignal.shared.postNotificationWithJson({
        "include_player_ids" : [ playerId],
        "contents" : {"en" : _nomeRemetente + " lhe mandou: " + mensagem.mensagem},
        "headings" : {"en" : "Você recebeu uma mensagem!"},
      });
    }

  }

  Future<String>_recuperarOsIdDestino() async {
    String _osIdDestinatario;
    //Firestore db = Firestore.instance;
    DocumentSnapshot snapshot = await db.collection("usuarios")
        .document( _idGrupoNome )
        .get();

    Map<String, dynamic> dados = snapshot.data;

    if( dados["osId"] != null){
      setState(() {
        _osIdDestinatario = dados["osId"];
      });
    }

    return _osIdDestinatario;
  }

    _salvarMensagem(
      String idRemetente, String idDestinatario, Mensagem msg) async {
    await db
        .collection("grupos")
        .document(widget.grupoNome)
        .collection("mensagens")
        .add(msg.toMap());

    //Limpa texto
    _controllerMensagem.clear();

  }

  _enviarFoto() async {
    PickedFile pf = await _imagePicker.getImage(source: ImageSource.camera) ;// await ImagePicker.pickImage(source: ImageSource.gallery);
    File imagemSelecionada = File(pf.path);
    _subindoImagem = true;
    String nomeImagem = DateTime.now().millisecondsSinceEpoch.toString();
    FirebaseStorage storage = FirebaseStorage.instance;
    StorageReference pastaRaiz = storage.ref();
    StorageReference arquivo = pastaRaiz
        .child("mensagens")
        .child( _idUsuarioLogado )
        .child( nomeImagem + ".jpg");

    //Upload da imagem
    StorageUploadTask task = arquivo.putFile( imagemSelecionada );

    //Controlar progresso do upload
    task.events.listen((StorageTaskEvent storageEvent){

      if( storageEvent.type == StorageTaskEventType.progress ){
        setState(() {
          _subindoImagem = true;
        });
      }else if( storageEvent.type == StorageTaskEventType.success ){
        setState(() {
          _subindoImagem = false;
        });
      }

    });

    //Recuperar url da imagem
    task.onComplete.then((StorageTaskSnapshot snapshot){
      _recuperarUrlImagem(snapshot);
    });
  }

  Future _recuperarUrlImagem(StorageTaskSnapshot snapshot) async {

    String url = await snapshot.ref.getDownloadURL();

    Mensagem mensagem = Mensagem();
    mensagem.idUsuario = _idUsuarioLogado;
    mensagem.mensagem = "";
    mensagem.timeStamp = Timestamp.now(); //LEK
    mensagem.urlImagem = url;
    mensagem.tipo = "imagem";

    //Salvar mensagem para remetente
    _salvarMensagem(_idUsuarioLogado, _idGrupoNome, mensagem);

    //Salvar mensagem para o destinatário
    _salvarMensagem(_idGrupoNome, _idUsuarioLogado, mensagem);

    _postarnotif(mensagem);

  }

  _recuperarDadosUsuario() async {
    FirebaseAuth auth = FirebaseAuth.instance;
    FirebaseUser usuarioLogado = await auth.currentUser();
    _idUsuarioLogado = usuarioLogado.uid;
    _idGrupoNome = widget.grupoNome;

    //Firestore db = Firestore.instance; // ja' eh atributo
    DocumentSnapshot snapshot = await db.collection("usuarios")
        .document( _idUsuarioLogado )
        .get();

    Map<String, dynamic> dados = snapshot.data;

    if( dados["urlImagem"] != null ){
      setState(() {
        _urlImagemRemetente = dados["urlImagem"];
        print("recuperou "+_urlImagemRemetente);
      });
    }
    if( dados["nome"] != null ){
      setState(() {
        _nomeRemetente = dados["nome"];
        print("recuperou "+_nomeRemetente);
      });
    }


    _adicionarListenerMensagens();

  }

  Stream<QuerySnapshot> _adicionarListenerMensagens(){

    final stream = db.
        collection("grupos")
        .document(widget.grupoNome)
        .collection("mensagens")
        .orderBy("timeStamp")  //LEK
        .snapshots()
    ;

    stream.listen((dados){
      _controller.add( dados );
      Timer(Duration(seconds: 1), (){
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      } );
    });

  }

  _removerMensagem(String idRemetente, String idDestinatario, Timestamp timeStamp) async {
    String id;
    Timestamp ultimaMensagem;

    await db
        .collection("mensagens")
        .document(idRemetente)
        .collection(idDestinatario)
        .where("timeStamp", isEqualTo: timeStamp)
        .limit(1)
        .getDocuments()
        .then((QuerySnapshot querySnapshot) => {
          id = querySnapshot.documents.first.documentID
    });

    await db
        .collection("mensagens")
        .document(idRemetente)
        .collection(idDestinatario)
        .document(id)
        .updateData({"mensagem" : "[Mensagem apagada]", "urlImagem" : ""});

    await db.collection("conversas")
        .document(_idUsuarioLogado)
        .collection("ultima_conversa")
        .document(_idGrupoNome)
        .get()
        .then((DocumentSnapshot doc) => {
          ultimaMensagem = doc.data["timeStamp"]
        });

    print(ultimaMensagem);
    print(timeStamp);

    if(ultimaMensagem==timeStamp){
      Mensagem mensagem = Mensagem();
      mensagem.timeStamp = timeStamp;
      mensagem.mensagem = "[Mensagem apagada]";
      mensagem.tipo = "texto";
      mensagem.idUsuario = _idUsuarioLogado;
    };
  }

  Widget _buildPopupDialog(BuildContext context, Timestamp timeStamp) {
    return new AlertDialog(
      title: const Text('Deletar', style: TextStyle(color: Colors.red)),
      content: new Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          InkWell(
            child: Text("Para você"),
            onTap: (){
              _removerMensagem(_idUsuarioLogado, _idGrupoNome, timeStamp);
              Navigator.of(context).pop();
            },
          ),
          Padding(
            padding: EdgeInsets.only(top: 40)
          ),
          InkWell(
            child: Text("Para ambos"),
            onTap: (){
              _removerMensagem(_idUsuarioLogado, _idGrupoNome, timeStamp);
              _removerMensagem(_idGrupoNome, _idUsuarioLogado, timeStamp);
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
      actions: <Widget>[
        new FlatButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          textColor: Theme.of(context).primaryColor,
          child: const Text('Fechar'),
        ),
      ],
    );
  }

  @override
  void initState() {
    super.initState();
    //_recuperarDadosRemetente();
    _recuperarDadosUsuario();
  }

  Future<void> initOneSignal() async{
    OneSignal.shared
        .setInAppMessageClickedHandler((OSInAppMessageAction action) {
    });
  }

  @override
  Widget build(BuildContext context) {

    var caixaMensagem = Container(
      padding: EdgeInsets.all(8),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: 8),
              child: TextField(
                controller: _controllerMensagem,
                autofocus: true,
                keyboardType: TextInputType.text,
                style: TextStyle(fontSize: 20),
                decoration: InputDecoration(
                    contentPadding: EdgeInsets.fromLTRB(32, 8, 32, 8),
                    hintText: "Digite uma mensagem...",
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(32)),
                    prefixIcon:
                      _subindoImagem
                        ? CircularProgressIndicator()
                        : IconButton(icon: Icon(Icons.camera_alt),onPressed: _enviarFoto)
                ),
              ),
            ),
          ),
          Platform.isIOS
              ? CupertinoButton(
                  child: Text("Enviar"),
                  onPressed: _enviarMensagem,
                )
              : FloatingActionButton(
                  backgroundColor: Color(0xff075E54),
                  child: Icon(
                    Icons.send,
                    color: Colors.white,
                  ),
                  mini: true,
                  onPressed: _enviarMensagem,
                )
        ],
      ),
    );

    var stream = StreamBuilder(
      stream: _controller.stream,
      builder: (context, snapshot) {
        switch (snapshot.connectionState) {
          case ConnectionState.none:
          case ConnectionState.waiting:
            return Center(
              child: Column(
                children: <Widget>[
                  Text("Carregando mensagens"),
                  CircularProgressIndicator()
                ],
              ),
            );
            break;
          case ConnectionState.active:
          case ConnectionState.done:

            QuerySnapshot querySnapshot = snapshot.data;

            if (snapshot.hasError) {
              return Text("Erro ao carregar os dados!");
            } else {
              return Expanded(
                child: ListView.builder(
                    controller: _scrollController,
                    itemCount: querySnapshot.documents.length,
                    itemBuilder: (context, indice) {

                      //recupera mensagem
                      List<DocumentSnapshot> mensagens = querySnapshot.documents.toList();
                      DocumentSnapshot item = mensagens[indice];

                      double larguraContainer =
                          MediaQuery.of(context).size.width * 0.8;

                      //Define cores e alinhamentos
                      Alignment alinhamento = Alignment.centerRight;
                      Color cor = Color(0xffd2ffa5);
                      if ( _idUsuarioLogado != item["idUsuario"] ) {
                        alinhamento = Alignment.centerLeft;
                        cor = Colors.white;
                      }

                      return Align(
                        alignment: alinhamento,
                        child: Padding(
                          padding: EdgeInsets.all(6),
                          child: InkWell(
                            onLongPress: (){
                              if ( _idUsuarioLogado == item["idUsuario"] ) {
                                Mensagem msgatual = Mensagem();
                                msgatual.idUsuario = item["idUsuario"];
                                msgatual.mensagem = item["mensagem"];
                                msgatual.timeStamp = item["timeStamp"];
                                msgatual.tipo = item["tipo"];
                                msgatual.urlImagem = item["uriImagem"];
                                print(msgatual.toMap());
                                showDialog(
                                  context: context,
                                  builder: (BuildContext context) => _buildPopupDialog(context, item["timeStamp"]),
                                );
                              }
                            },
                            child: Container(
                              width: larguraContainer,
                              padding: EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                  color: cor,
                                  borderRadius:
                                  BorderRadius.all(Radius.circular(8))),
                              child:
                              item["tipo"] == "texto"
                                  ? Text(item["mensagem"],style: TextStyle(fontSize: 18),)
                                  : Image.network(item["urlImagem"]),
                            ),
                          )
                        ),
                      );
                    }),
              );
            }

            break;
        }
      },
    );

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: <Widget>[
            Padding(
              padding: EdgeInsets.only(left: 8),
              child: Text(widget.grupoNome),
            )
          ],
        ),
      ),
      body: Container(
        width: MediaQuery.of(context).size.width,
        decoration: BoxDecoration(
            image: DecorationImage(
                image: AssetImage("imagens/bg.png"), fit: BoxFit.cover)),
        child: SafeArea(
            child: Container(
          padding: EdgeInsets.all(8),
          child: Column(
            children: <Widget>[
              stream,
              caixaMensagem,
            ],
          ),
        )),
      ),
    );
  }
}