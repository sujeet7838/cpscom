import 'dart:io';

import 'package:chat_bubbles/bubbles/bubble_normal_image.dart';
import 'package:chat_bubbles/bubbles/bubble_special_one.dart';
import 'package:chat_bubbles/bubbles/bubble_special_three.dart';
import 'package:chat_bubbles/bubbles/bubble_special_two.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cpscom_admin/Commons/commons.dart';
import 'package:cpscom_admin/Features/GroupInfo/Presentation/group_info_screen.dart';
import 'package:cpscom_admin/Utils/app_helper.dart';
import 'package:cpscom_admin/Widgets/custom_app_bar.dart';
import 'package:cpscom_admin/Widgets/custom_text_field.dart';
import 'package:eva_icons_flutter/eva_icons_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../Widgets/custom_confirmation_dialog.dart';
import '../../GroupMedia/Presentation/group_media_screen.dart';

class ChatScreen extends StatefulWidget {
  final QueryDocumentSnapshot groupDetails;
  final bool? isAdmin;

  const ChatScreen({Key? key, required this.groupDetails, this.isAdmin})
      : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController msgController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  File? imageFile;

  final ScrollController _scrollController = ScrollController();

  // Future getImage() async {
  //   ImagePicker _picker = ImagePicker();
  //   final List<XFile>? images = await _picker.pickMultiImage().then((value) {
  //     if (value != null) {
  //       for (var i = 0; i < value.length; i++) {
  //         imageFile = File(value[i].path);
  //         //print("imagefile" + imageFile.toString());
  //         uploadImage();
  //       }
  //     }
  //     //return null;
  //   });
  // }

  void onSendMessage() async {
    if (msgController.text.trim().isNotEmpty) {
      Map<String, dynamic> chatData = {
        "sendBy": _auth.currentUser!.displayName,
        "message": msgController.text,
        "type": "text",
        "time": FieldValue.serverTimestamp(),
        "isSeen": false,
        "isSender": true,
      };

      msgController.clear();
      await _firestore
          .collection('users')
          .doc(_auth.currentUser!.uid)
          .collection('groups')
          .doc(widget.groupDetails.id)
          .collection('chats')
          .add(chatData);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: widget.groupDetails['name'],
        actions: [
          PopupMenuButton(
            icon: CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.lightGrey,
              foregroundImage: NetworkImage(
                  "${AppStrings.imagePath}${widget.groupDetails['profile_picture']}"),
            ),
            itemBuilder: (context) => [
              PopupMenuItem(
                  value: 1,
                  child: Text(
                    'Group Info',
                    style: Theme.of(context)
                        .textTheme
                        .bodyText2!
                        .copyWith(color: AppColors.black),
                  )),
              PopupMenuItem(
                  value: 2,
                  child: Text(
                    'Group Media',
                    style: Theme.of(context)
                        .textTheme
                        .bodyText2!
                        .copyWith(color: AppColors.black),
                  )),

            ],
            onSelected: (value) {
              switch (value) {
                case 1:
                  context.push(GroupInfoScreen(
                    groupDetails: widget.groupDetails,
                    isAdmin: widget.isAdmin!,
                  ));
                  break;
                case 2:
                  context.push(const GroupMediaScreen());
                  break;
              }
            },
          ),
        ],
      ),
      body: _BuildChats(
        groupId: widget.groupDetails.id,
      ),
      bottomSheet: SafeArea(
        bottom: true,
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.white,
            boxShadow: [
              BoxShadow(
                  offset: Offset(-5, -5),
                  color: AppColors.lightGrey,
                  blurRadius: 10)
            ],
          ),
          padding: const EdgeInsets.all(AppSizes.kDefaultPadding),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.kDefaultPadding),
                  decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius:
                          BorderRadius.circular(AppSizes.cardCornerRadius * 3),
                      border:
                          Border.all(width: 0.3, color: AppColors.secondary)),
                  child: CustomTextField(
                    controller: msgController,
                    hintText: 'Type here...',
                  ),
                ),
              ),
              const SizedBox(
                width: AppSizes.kDefaultPadding,
              ),
              GestureDetector(
                onTap: onSendMessage,
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppColors.buttonGradientColor),
                  child: const Icon(
                    EvaIcons.navigation2,
                    color: AppColors.white,
                    size: 24,
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}

class _BuildChats extends StatefulWidget {
  final String groupId;

  const _BuildChats({Key? key, required this.groupId}) : super(key: key);

  @override
  State<_BuildChats> createState() => _BuildChatsState();
}

class _BuildChatsState extends State<_BuildChats> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollController.animateTo(_scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 200), curve: Curves.easeInOut);
    });

    super.initState();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
        stream: _firestore
            .collection('users')
            .doc(_auth.currentUser!.uid)
            .collection('groups')
            .doc(widget.groupId)
            .collection('chats')
            .orderBy('time')
            .snapshots(),
        builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (snapshot.hasData) {
            return ListView.builder(
                controller: _scrollController,
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  Map<String, dynamic> chatMap =
                      snapshot.data!.docs[index].data() as Map<String, dynamic>;
                  // bool sender = false;
                  // if (chatMap['sendby'] == _auth.currentUser!.uid) {
                  //   setState(() {
                  //     sender = true;
                  //   });
                  // }
                  return Column(
                    children: [
                      chatMap['type'] == 'text'
                          ? BubbleSpecialOne(
                              text: chatMap['message'],
                              textStyle: Theme.of(context)
                                  .textTheme
                                  .bodyText1!
                                  .copyWith(fontWeight: FontWeight.w400),
                              color: chatMap['isSender'] == true
                                  ? AppColors.secondary.withOpacity(0.1)
                                  : AppColors.shimmer,
                              sent: true,
                              isSender:
                                  chatMap['isSender'] == true ? true : false,
                            )
                          : BubbleNormalImage(
                              id: 'id001',
                              image: Image.network(chatMap['message'])),
                      Align(
                          alignment: chatMap['isSender'] == true
                              ? Alignment.bottomRight
                              : Alignment.bottomLeft,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8.0, vertical: 4),
                            child: Text(
                              AppHelper.getDateFromString(
                                  (chatMap['time'] as Timestamp)
                                      .toDate()
                                      .toString()),
                              style: Theme.of(context).textTheme.bodyText2,
                            ),
                          ))
                    ],
                  );
                  // Text(
                  //   chatMap['type'] == 'text' ? chatMap['message'] : '');
                });
          }
          return const SizedBox();
        });
  }
}
