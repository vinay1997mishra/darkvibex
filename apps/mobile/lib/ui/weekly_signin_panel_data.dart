import 'dart:convert';
import 'dart:typed_data';

import 'weekly_signin_b64/chunk_01.dart';
import 'weekly_signin_b64/chunk_02.dart';
import 'weekly_signin_b64/chunk_03.dart';
import 'weekly_signin_b64/chunk_04.dart';
import 'weekly_signin_b64/chunk_05.dart';
import 'weekly_signin_b64/chunk_06.dart';
import 'weekly_signin_b64/chunk_07.dart';
import 'weekly_signin_b64/chunk_08.dart';

final Uint8List weeklySignInPanelBytes = base64Decode(
  weeklySignInB64Chunk01 +
      weeklySignInB64Chunk02 +
      weeklySignInB64Chunk03 +
      weeklySignInB64Chunk04 +
      weeklySignInB64Chunk05 +
      weeklySignInB64Chunk06 +
      weeklySignInB64Chunk07 +
      weeklySignInB64Chunk08,
);
