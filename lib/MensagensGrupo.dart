// Cabeçalho:
//  Este módulo é responsável por definir a tela de conversa em grupo e todas suas funcionalidades.
//  1.Para implementar a notificação. Foi modificado o método para mandar a notificação para cada integrante do grupo.
//  1.1.Isto funciona tanto para uma mensagem de texto, quanto uma foto.
//  2.Para implementar a remoção de mensagens foram modificados os métodos _removerMensagem e _buildPopupDialog.
//  2.1.O _buildPopupDialog abre uma janela quando a mensagem é pressionada por um tempo, confirmando a exclusão da mensagem.
//  2.2.O _removerMensagem acessa o Firebase e procura a mensagem a ser removida pelo seu timestamp, em seguida trocando o texto da mensagem para "[Mensagem apagada]"
//  3.Para implementar a detecção de links, foram usados os plugins url_launcher e link_text

// TODO: implementar anexos do Mensagens.dart para cá;

import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:link_text/link_text.dart';
import 'package:url_launcher/url_launcher.dart';
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
  String grupoId;

  MensagensGrupo(this.grupoId);

  @override
  _MensagensGrupoState createState() => _MensagensGrupoState();
}

class _MensagensGrupoState extends State<MensagensGrupo> {
  File _imagem;
  bool _subindoImagem = false;
  String _idUsuarioLogado = "";
  String _idGrupo = "";
  String _grupoNome = "";
  String _urlImagemRemetente="blz2"; // Remetente eh o logado
  String _nomeRemetente="blz2";

  List<String> itensMenu = [
    "Câmera", "Galeria", "Documento",
  ];

  final Map<String, String> _mapaUsuarios = {};



  static ImagePicker _imagePicker = null;

  Firestore db = Firestore.instance;
  TextEditingController _controllerMensagem = TextEditingController();

  final _controller = StreamController<QuerySnapshot>.broadcast();
  ScrollController _scrollController = ScrollController();


  _MensagensGrupoState(){
    if (_imagePicker == null)
      _imagePicker = ImagePicker();
  }

  _recuperarNomeGrupo() async{
    Firestore db = Firestore.instance;

    DocumentSnapshot grupodata = await db.collection("grupos").document(widget.grupoId).get();

    setState(() {
      _grupoNome = grupodata.data["nome"];
    });


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
      _salvarMensagem(_idUsuarioLogado, _idGrupo, mensagem);

      //abv
      _postarnotif(mensagem);

    }
  }

  _postarnotif(Mensagem mensagem) async {
    var status = await OneSignal.shared.getPermissionSubscriptionState();

    var playerId = await _recuperarOsIdDestino();

    var response;

    if(mensagem.urlImagem != ""){
      response = await OneSignal.shared.postNotificationWithJson({
        "include_player_ids" : playerId,
        "contents" : {"en" : "abra o app para ver a imagem "}, // se não tiver isso a notificação não funfa
        "headings" : {"en" : "Você recebeu uma imagem!"},
      });
    }
    else{
      response = await OneSignal.shared.postNotificationWithJson({
        "include_player_ids" : playerId,
        "contents" : {"en" : _nomeRemetente + " do grupo " + _grupoNome + " lhe mandou: " + mensagem.mensagem},
        "headings" : {"en" : "Você recebeu uma mensagem!"},
      });
    }



  }

  Future<List<String>> _recuperarOsIdDestino() async {

    QuerySnapshot query = await db.collection("grupos")
        .document( widget.grupoId )
        .collection("integrantes")
        .getDocuments();

    List<String> idList = [];
    for(DocumentSnapshot item in query.documents){
      DocumentSnapshot ds = await db.collection("usuarios").document(item.documentID).get();
      idList.add(ds.data["osId"]);
    }

    return idList;
  }

  _salvarMensagem(
      String idRemetente, String idDestinatario, Mensagem msg) async {
    await db
        .collection("grupos")
        .document(widget.grupoId)
        .collection("mensagens")
        .add(msg.toMap());

    //Limpa texto
    _controllerMensagem.clear();

  }

  _enviarFoto(String source) async {
    PickedFile pf;
    if(source=="Camera") {
      pf = await _imagePicker.getImage(source: ImageSource
          .camera); // await ImagePicker.pickImage(source: ImageSource.gallery);
    }
    else if(source=="Galeria") {
      pf = await _imagePicker.getImage(source: ImageSource
          .gallery); // await ImagePicker.pickImage(source: ImageSource.gallery);
    }
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

  _enviarArquivo() async {
    String URL;
    File result = await FilePicker.getFile(
      type: FileType.custom,
      allowedExtensions: ['docx','pdf', 'txt', 'doc'],
    );

    if(result != null) {
      print(result.path);
      print(_uploadFile(result, result.path.split('.').last, result.path.split('/').last));
    } else {
      // User canceled the picker
    }
  }

  Future<String> _uploadFile(File file, String ext, String filename) async {
    _subindoImagem = true;
    String filename = DateTime.now().millisecondsSinceEpoch.toString();
    FirebaseStorage storage = FirebaseStorage.instance;
    StorageReference pastaRaiz = storage.ref();
    StorageReference arquivo = pastaRaiz
        .child("mensagens")
        .child( _idUsuarioLogado )
        .child( filename +'.'+ext);

    //Upload da imagem
    StorageUploadTask task = arquivo.putFile( file );

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
    String URL;

    //Recuperar url da imagem
    task.onComplete.then((StorageTaskSnapshot snapshot) async {
      List<String> imgExt = ['png', 'jpg'];
      List<String> docExt = ['docx','pdf', 'txt', 'doc'];
      List<String> vidExt = ['mp4'];
      if (imgExt.contains(ext)) {
        URL = await _recuperarUrlImagem(snapshot);

      } else if(docExt.contains(ext)){
        URL = await arquivo.getDownloadURL();
        print(URL);
        //launch(URL); // abre navegador para download ideal seria abrir para leitura

        String textoMensagem = URL;
        if (textoMensagem.isNotEmpty) {
          Mensagem mensagem = Mensagem();
          mensagem.idUsuario = _idUsuarioLogado;
          mensagem.mensagem = filename;
          mensagem.timeStamp = Timestamp.now(); //LEK
          mensagem.urlImagem = textoMensagem;
          mensagem.tipo = "arquivo";

          //Salvar mensagem para remetente
          _salvarMensagem(_idUsuarioLogado, _idGrupo, mensagem);

          //abv
          _postarnotif(mensagem);

        }

      } else if(vidExt.contains(ext)) {

      }
      return URL;
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

    _salvarMensagem(_idUsuarioLogado, _idGrupo, mensagem);

    _postarnotif(mensagem);

  }

  _recuperarDadosUsuario() async {
    FirebaseAuth auth = FirebaseAuth.instance;
    FirebaseUser usuarioLogado = await auth.currentUser();
    _idUsuarioLogado = usuarioLogado.uid;
    _idGrupo = widget.grupoId;

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
        .document(widget.grupoId)
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
        .collection("grupos").document(widget.grupoId)
        .collection("mensagens")
        .where("timeStamp", isEqualTo: timeStamp)
        .limit(1)
        .getDocuments()
        .then((QuerySnapshot querySnapshot) => {
      id = querySnapshot.documents.first.documentID
    });

    await db
        .collection("grupos").document(widget.grupoId)
        .collection("mensagens")
        .document(id)
        .updateData({"mensagem" : "[Mensagem apagada]", "urlImagem" : ""});

  }

  Widget _buildPopupDialog(BuildContext context, Timestamp timeStamp) {
    return new AlertDialog(
      title: const Text('Deletar em grupo deleta para todos. Deletar?', style: TextStyle(color: Colors.red)),
      content: new Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          InkWell(
            child: Text("Sim"),
            onTap: (){
              _removerMensagem(_idUsuarioLogado, _idGrupo, timeStamp);
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
          child: const Text('Cancelar'),
        ),
      ],
    );
  }

  Future<String> _procuraNome(String id) async {
    String nome;
    await db
        .collection("usuarios")
        .document(id)
        .get()
        .then((DocumentSnapshot doc) => {
      nome = doc.data["nome"]
    });
    print("mapatual");
    print(_mapaUsuarios);
    return nome;
  }

  _recuperaUsuarios() async{
    String id;
    String nome;
    await db
        .collection("grupos").document(widget.grupoId)
        .collection("integrantes")
        .getDocuments()
        .then((QuerySnapshot querySnapshot) => {
      querySnapshot.documents.forEach((doc) {
        _mapaUsuarios[doc.documentID] = doc["nome"];
      })
    });
  }

  _escolhaMenuItem(String itemEscolhido){

    switch( itemEscolhido ){
      case "Câmera":
        _enviarFoto("Camera");
        break;
      case "Galeria":
        _enviarFoto("Galeria");
        break;
      case "Documento":
        _enviarArquivo();
        break;
    }
    //print("Item escolhido: " + itemEscolhido );

  }

  @override
  void initState() {
    super.initState();
    _recuperarNomeGrupo();
    _recuperarDadosUsuario();
    print("Recuperando usuarios");
    _recuperaUsuarios();

  }

  Future<void> initOneSignal() async{
    OneSignal.shared
        .setInAppMessageClickedHandler((OSInAppMessageAction action) {
    });
  }

  Widget _msgWidgetBuilder(Mensagem msg){
    switch(msg.tipo){
      case "texto":

        return LinkText(
            text: msg.mensagem,
            textStyle: TextStyle(fontSize: 18),
            linkStyle: TextStyle(
                fontSize: 18,
                color: Colors.lightBlue,
                decoration: TextDecoration.underline
            )
        );

        break;

      case "imagem":

        return Image.network(msg.urlImagem);

        break;

      default:


        return Row(children: [
          Flexible(
              child: Text(msg.mensagem,
              )
          ),
          IconButton(
            icon: Icon(Icons.download_rounded),
            onPressed: (){
              launch(msg.urlImagem);
            },
          ),
        ]
        );

        break;
    }

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
                      String nome = "Sistema";
                      if(item["idUsuario"]!="sistema"){
                        nome = _mapaUsuarios[item["idUsuario"]];
                      }
                      if ( _idUsuarioLogado != item["idUsuario"] ) {
                        alinhamento = Alignment.centerLeft;
                        cor = Colors.white;
                      }

                      Mensagem msgatual = Mensagem();
                      msgatual.idUsuario = item["idUsuario"];
                      msgatual.mensagem = item["mensagem"];
                      msgatual.timeStamp = item["timeStamp"];
                      msgatual.tipo = item["tipo"];
                      msgatual.urlImagem = item["urlImagem"];

                      return Align(
                        alignment: alinhamento,
                        child: Padding(
                            padding: EdgeInsets.all(6),
                            child: InkWell(
                              onLongPress: (){
                                if ( _idUsuarioLogado == item["idUsuario"] ) {
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
                                _msgWidgetBuilder(msgatual)
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
              child: Text(_grupoNome),
            )
          ],
        ),
        actions: <Widget>[
          PopupMenuButton<String>(
            icon: Icon(Icons.attach_file),
            onSelected: _escolhaMenuItem,
            itemBuilder: (context){
              return itensMenu.map((String item){
                return PopupMenuItem<String>(
                  value: item,
                  child: Text(item),
                );
              }).toList();
            },
          )
        ],
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
