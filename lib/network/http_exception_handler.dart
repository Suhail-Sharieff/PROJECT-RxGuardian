import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:rxGuardian/widgets/show_toast.dart';

class HttpExceptionHandler{
  static void handle(Exception error, BuildContext context) {
    if (error is SocketException) {
      showToast(context,"No Internet connection!",ToastType.ERROR);
    } else if (error is TimeoutException) {
      showToast(context,"Server timed out!",ToastType.ERROR);
    } else {
      log("Unknown error: $error");
      showToast(context,"Something went wrong!",ToastType.ERROR);
    }
    throw Exception(error.toString());
  }


}