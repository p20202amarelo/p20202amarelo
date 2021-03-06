// Cabeçalho:
//  Este módulo é responsável por definir a tela de conversa e todas suas funcionalidades.
//  1.Para implementar a notificação. Quando o botão de enviar é apertado, o osId é recuperado pelo Firestore, e uma notificação é postada para o osId do destinatário.
//  1.1.Isto funciona tanto para uma mensagem de texto, quanto uma foto ou arquivo.
//  2.Para implementar a remoção de mensagens foram criados os métodos _removerMensagem e _buildPopupDialog.
//  2.1.O _buildPopupDialog abre uma janela quando a mensagem é pressionado por um tempo, apresentando duas opções para o usuário e então chama _removerMensagem.
//  2.2.O _removerMensagem acessa o Firebase e procura a mensagem a ser removida pelo seu timestamp, em seguida trocando o texto da mensagem para "[Mensagem apagada]"
//  3.Para implementar a detecção de links, foram usados os plugins url_launcher e link_text
//  4.Para implementar os anexos, foi implementado o plugin file_picker e image_picker.
//  5.Implementado _escolhaMenuItem para que o usuario possa escolher entre enviar fotos ou documentos

import 'dart:async';

import 'package:file_picker/file_picker.dart';
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
import 'package:link_text/link_text.dart';
import 'package:url_launcher/url_launcher.dart';


class Mensagens extends StatefulWidget {
  Usuario contato;

  Mensagens(this.contato);

  @override
  _MensagensState createState() => _MensagensState();
}



class _MensagensState extends State<Mensagens> {

  List<String> itensMenu = [
    "Câmera", "Galeria", "Documento",
  ];

  File _imagem;
  bool _subindoImagem = false;
  String _idUsuarioLogado;
  String _idUsuarioDestinatario;
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
      _salvarMensagem(_idUsuarioLogado, _idUsuarioDestinatario, mensagem);

      //Salvar mensagem para o destinatário
      _salvarMensagem(_idUsuarioDestinatario, _idUsuarioLogado, mensagem);

      //Salvar conversa
      _salvarConversa( mensagem );

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
        "contents" : {"en" : "abra o app para ver a imagem "}, // se não tiver isso a notificação não funciona
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
        .document( _idUsuarioDestinatario )
        .get();

    Map<String, dynamic> dados = snapshot.data;

    if( dados["osId"] != null){
      setState(() {
        _osIdDestinatario = dados["osId"];
      });
    }

    return _osIdDestinatario;
  }

  _salvarConversa(Mensagem msg){

    //Salvar conversa PARA remetente
    Conversa cRemetente = Conversa();
    cRemetente.idRemetente = _idUsuarioLogado;
    cRemetente.idDestinatario = _idUsuarioDestinatario;
    cRemetente.mensagem = msg.mensagem;
    cRemetente.nome = widget.contato.nome; //_nomeDestinatario;   // tem que ficar o nome do destinatario
    //print("cRemetente.nome="+cRemetente.nome);
    cRemetente.timeStamp = msg.timeStamp; //"LEK
    cRemetente.caminhoFoto = widget.contato.urlImagem; //_urlImagemDestinatario;  // tem que ficar a imagem do destinatario
    //print("cRemetente.caminhoFoto="+cRemetente.caminhoFoto);
    cRemetente.tipoMensagem = msg.tipo;
    cRemetente.arquivada = false;
    cRemetente.salvar();

    //Salvar conversa PARA o destinatario
    Conversa cDestinatario = Conversa();
    cDestinatario.idRemetente = _idUsuarioDestinatario;  // troca para que o destinatario possa recuperar a ultima mesmo nao sido criada por ele
    cDestinatario.idDestinatario = _idUsuarioLogado;
    cDestinatario.mensagem = msg.mensagem;

    //_recuperarDadosRemetente();
    cDestinatario.nome = _nomeRemetente; // vai exibir no nome do remetente
    //print("cDestinatario.nome="+cDestinatario.nome);
    cDestinatario.timeStamp = msg.timeStamp; //LEK
    cDestinatario.caminhoFoto = _urlImagemRemetente; // vai exibir a imagem do remetente
    //print("cDestinatario.caminhoFoto="+cDestinatario.caminhoFoto);
    cDestinatario.tipoMensagem = msg.tipo;
    cDestinatario.arquivada = false;
    cDestinatario.salvar();

  }

  Future<void> downloadFile() async {

    FirebaseStorage storage = FirebaseStorage.instance;
    StorageReference pastaRaiz = storage.ref();
    StorageReference ref = pastaRaiz
        .child("mensagens")
        .child( _idUsuarioLogado )
        .child( "/1617168607361.pdf");


    print(ref.getName());


    final File tempDir = File('sdk_gphone_x86/Download');
    final File tempFile = File('${tempDir.path}/tmp.pdf');

    final StorageFileDownloadTask task = ref.writeToFile(tempFile);
    FileDownloadTaskSnapshot snapshot = await task.future;

    // String name = await ref.getName();
    // String path = await ref.getPath();

  }

  _salvarMensagem(
      String idRemetente, String idDestinatario, Mensagem msg) async {
    await db
        .collection("mensagens")
        .document(idRemetente)
        .collection(idDestinatario)
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
    _uploadFile(imagemSelecionada, imagemSelecionada.path.split('.').last, imagemSelecionada.path.split('/').last);

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
        //launch(URL);

        String textoMensagem = URL;
        if (textoMensagem.isNotEmpty) {
          Mensagem mensagem = Mensagem();
          mensagem.idUsuario = _idUsuarioLogado;
          mensagem.mensagem = filename;
          mensagem.timeStamp = Timestamp.now(); //LEK
          mensagem.urlImagem = textoMensagem;
          mensagem.tipo = "arquivo";

          //Salvar mensagem para remetente
          _salvarMensagem(_idUsuarioLogado, _idUsuarioDestinatario, mensagem);

          //Salvar mensagem para o destinatário
          _salvarMensagem(_idUsuarioDestinatario, _idUsuarioLogado, mensagem);

          //Salvar conversa
          _salvarConversa( mensagem );

          //abv
          _postarnotif(mensagem);

        }

      } else if(vidExt.contains(ext)) {

      }
      return URL;
    });


  }

  Future<String> _recuperarUrlImagem(StorageTaskSnapshot snapshot) async {

    String url = await snapshot.ref.getDownloadURL();

    Mensagem mensagem = Mensagem();
    mensagem.idUsuario = _idUsuarioLogado;
    mensagem.mensagem = "";
    mensagem.timeStamp = Timestamp.now(); //LEK
    mensagem.urlImagem = url;
    mensagem.tipo = "imagem";

    //Salvar mensagem para remetente
    _salvarMensagem(_idUsuarioLogado, _idUsuarioDestinatario, mensagem);

    //Salvar mensagem para o destinatário
    _salvarMensagem(_idUsuarioDestinatario, _idUsuarioLogado, mensagem);

    _postarnotif(mensagem);

    _salvarConversa( mensagem );
    return url;
  }

  _recuperarDadosUsuario() async {
    FirebaseAuth auth = FirebaseAuth.instance;
    FirebaseUser usuarioLogado = await auth.currentUser();
    _idUsuarioLogado = usuarioLogado.uid;
    _idUsuarioDestinatario = widget.contato.idUsuario;

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

    final stream = db.collection("mensagens")
        .document(_idUsuarioLogado)
        .collection(_idUsuarioDestinatario)
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
        .updateData({"mensagem" : "[Mensagem apagada]", "urlImagem" : "", "tipo" : "texto"});

    await db.collection("conversas")
        .document(_idUsuarioLogado)
        .collection("ultima_conversa")
        .document(_idUsuarioDestinatario)
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
      _salvarConversa(mensagem);
    };
  }

  _removerArquivo(String filepath) async {
    var firebaseStorage_instance = FirebaseStorage.instance;
    StorageReference sr = await firebaseStorage_instance.getReferenceFromUrl(filepath);
    sr.delete();
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
      //downloadFile();
      //Navigator.pushNamed(context, "/criargrupo");
        break;
    }
    //print("Item escolhido: " + itemEscolhido );

  }

  Widget _buildPopupDialog(BuildContext context, Timestamp timeStamp, String urlImagem) { // by renan
    return new AlertDialog(
      title: const Text('Deletar', style: TextStyle(color: Colors.red)),
      content: new Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          InkWell(
            child: Text("Para você"),
            onTap: (){
              _removerMensagem(_idUsuarioLogado, _idUsuarioDestinatario, timeStamp);
              Navigator.of(context).pop();
            },
          ),
          Padding(
              padding: EdgeInsets.only(top: 40)
          ),
          InkWell(
            child: Text("Para ambos"),
            onTap: (){
              _removerMensagem(_idUsuarioLogado, _idUsuarioDestinatario, timeStamp);
              _removerMensagem(_idUsuarioDestinatario, _idUsuarioLogado, timeStamp);
              _removerArquivo(urlImagem);
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
                            padding: EdgeInsets.all(6),//remove mensagem
                            child: InkWell(
                              onLongPress: (){
                                if ( _idUsuarioLogado == msgatual.idUsuario ) {
                                  print(msgatual.toMap());
                                  showDialog(
                                    context: context,
                                    builder: (BuildContext context) => _buildPopupDialog(context, msgatual.timeStamp, item["urlImagem"]),
                                  );//remove mensagem
                                }
                              },
                              child: Container(
                                width: larguraContainer,
                                padding: EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                    color: cor,
                                    borderRadius:
                                    BorderRadius.all(Radius.circular(8))),
                                child: _msgWidgetBuilder(msgatual)
                              )
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
            CircleAvatar(
                maxRadius: 20,
                backgroundColor: Colors.grey,
                backgroundImage: widget.contato.urlImagem != null
                    ? NetworkImage(widget.contato.urlImagem)
                    : null),
            Padding(
              padding: EdgeInsets.only(left: 8),
              child: Text(widget.contato.nome),
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
