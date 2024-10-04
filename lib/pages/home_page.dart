
import 'dart:typed_data';

import 'package:dash_chat_2/dash_chat_2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gemini/flutter_gemini.dart';
import 'package:image_picker/image_picker.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Gemini _gemini = Gemini.instance;

  ChatUser user = ChatUser(id: '1', firstName: 'User');
  ChatUser chatBot = ChatUser(id: '2', firstName: 'Bot');
  List<ChatMessage> messages = <ChatMessage>[];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text("ChatBot"),
      ),
      body: DashChat(
        inputOptions: InputOptions(trailing: [
          IconButton(
              onPressed: () {
                _sendMediaMessage();
              },
              icon: Icon(Icons.image))
        ]),
        currentUser: user,
        onSend: _sendMessage,
        messages: messages,
      ),
    );
  }

  void _sendMessage(ChatMessage m) async {
    setState(() {
      messages.insert(0, m);
    });
    try {
      String conversationContext = messages
          .take(messages.length)
          .map((msg) => msg.user.firstName! + ": " + msg.text)
          .join("\n");
      String question = m.text;
      List<Uint8List>? images;

      // Xử lý ảnh từ XFile
      if (m.medias?.isNotEmpty ?? false) {
        try {
          XFile imageFile = XFile(m.medias!.first.url);
          images = [await imageFile.readAsBytes()];
        } catch (e) {
          print("Error reading image file: $e");
          images = null;
        }
      }

      // Gọi API của Gemini với văn bản và ảnh (nếu có)
      _gemini
          .streamGenerateContent(conversationContext + "\n" + question, images: images)
          .listen((event) {
        ChatMessage? lastMessage = messages.firstOrNull;
        if (lastMessage != null && lastMessage.user == chatBot) {
          messages.removeAt(0);
          String response =
              event.content?.parts?.fold("", (pre, cur) => "$pre${cur.text}") ??
                  "";
          lastMessage.text += response;
          setState(() {
            messages.insert(0, lastMessage);
          });
        } else {
          String response =
              event.content?.parts?.fold("", (pre, cur) => "$pre${cur.text}") ??
                  "";
          ChatMessage message = ChatMessage(
              user: chatBot, createdAt: DateTime.now(), text: response);
          setState(() {
            messages.insert(0, message);
          });
        }
      });
    } catch (e) {
      print(e);
    }
  }


  void _sendMediaMessage() async {
    ImagePicker imagePicker = ImagePicker();
    XFile? file = await imagePicker.pickImage(source: ImageSource.gallery);
    if (file != null) {

        print(file.path);
      ChatMessage chatMessage = ChatMessage(
          user: user,
          createdAt: DateTime.now(),
          text: "Mô tả hình này",
          medias: [
            ChatMedia(url: file.path, fileName: "", type: MediaType.image)
          ]);
      _sendMessage(chatMessage);
    }
  }
}
