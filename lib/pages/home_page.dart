
  import 'dart:convert';
  import 'package:dash_chat_2/dash_chat_2.dart';
  import 'package:flutter/foundation.dart';
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
    bool isTyping = false;
    late String imageUrl="";
    @override
    Widget build(BuildContext context) {
      return Scaffold(
        appBar: AppBar(
          centerTitle: true,
          title: const Text("ChatBot"),
        ),
        body: Column(
          children: [
            Expanded(
              child: DashChat(
                inputOptions: InputOptions(
                    inputDisabled: isTyping,
                    trailing: [
                  IconButton(
                    onPressed: () {
                      _sendMediaMessage();
                    },
                    icon: Icon(Icons.image),
                  )
                ]),
                currentUser: user,
                onSend: _sendMessage,
                messages: messages,
                typingUsers: isTyping ? [chatBot] : [],
                messageOptions: MessageOptions(
                  messageMediaBuilder: (ChatMessage message, ChatMessage? previousMessage, ChatMessage? nextMessage) {
                    // Check if the message contains media
                    if (message.medias != null && message.medias!.isNotEmpty) {
                      return Image.network(
                        message.medias!.first.url,
                        width: 150,
                        height: 150,
                        fit: BoxFit.cover,
                      );
                    } else {
                      return SizedBox.shrink(); // Return an empty widget if no media is present
                    }
                  },
                ),
              ),
            ),
            if (imageUrl != "")
              if (imageUrl != null)
                Container(
                  margin: EdgeInsets.all(8),
                  child: Stack(
                    alignment: Alignment.centerRight,
                    children: [
                      Image.network(
                        imageUrl!,
                        width: 150,
                        height: 150,
                        fit: BoxFit.cover,
                      ),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: IconButton(
                          icon: Icon(Icons.close, color: Colors.red),
                          onPressed: () {
                            setState(() {
                              imageUrl = ""; // Xóa hình ảnh được chọn
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),
          ],
        )

      );
    }

    void _sendMessage(ChatMessage m) async {
      setState(() {
        messages.insert(0, m);
        isTyping = true;
      });
      try {
        String conversationContext = messages
            .take(messages.length)
            .map((msg) => msg.user.firstName! + ": " + msg.text)
            .join("\n");
        String question = m.text;
        List<Uint8List>? images;
        if(imageUrl.isNotEmpty)
          {
            m.medias ??= [];
            m.medias!.add(ChatMedia(url: imageUrl, fileName: "", type: MediaType.image));
            setState(() {
              imageUrl="";
            });
        if (m.medias?.isNotEmpty ?? false) {
          try {
            XFile imageFile = XFile(m.medias!.first.url);
            images = [await imageFile.readAsBytes()];
          } catch (e) {
            print("Error reading image file: $e");
            images = null;
          }
        }}

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
        }, onDone: () {
          setState(() {
            isTyping = false;
          });
        });
      } catch (e) {
        print(e);
        setState(() {
          isTyping = false;
        });
      }
    }

    void _sendMediaMessage() async {
      ImagePicker imagePicker = ImagePicker();
      XFile? file = await imagePicker.pickImage(source: ImageSource.gallery);
      if (file != null) {
        String url;
        if (kIsWeb) {
          Uint8List imageBytes = await file.readAsBytes();
          String base64Image = base64Encode(imageBytes);

          url = 'data:image/png;base64,$base64Image';
        } else {
          url = file.path;
        }
        setState(() {
          imageUrl=url;
        });
      }
    }
  }