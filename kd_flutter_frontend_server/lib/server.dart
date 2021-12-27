// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart=2.8
library flutter_frontend_server;

import 'dart:async';
import 'dart:io' hide FileSystemEntity;

import 'package:args/args.dart';
import 'package:frontend_server/frontend_server.dart' as frontend
    show
        FrontendCompiler,
        CompilerInterface,
        listenAndCompile,
        argParser,
        usage,
        ProgramTransformer;
import 'package:path/path.dart' as path;
import 'package:vm/incremental_compiler.dart';
import 'package:vm/target/flutter.dart';

import 'transformer/aop/aop_transformer.dart';

class _FlutterFrontendCompiler implements frontend.CompilerInterface {
  frontend.CompilerInterface _compiler;

  final AspectdAopTransformer aspectdAopTransformer = AspectdAopTransformer();

  _FlutterFrontendCompiler(StringSink output,
      {bool unsafePackageSerialization,
        bool useDebuggerModuleNames,
        bool emitDebugMetadata,
        frontend.ProgramTransformer transformer})
      : _compiler = frontend.FrontendCompiler(output,
      transformer: transformer,
      useDebuggerModuleNames: useDebuggerModuleNames,
      emitDebugMetadata: emitDebugMetadata,
      unsafePackageSerialization: unsafePackageSerialization);

  @override
  Future<bool> compile(String entryPoint, ArgResults options,
      {IncrementalCompiler generator}) async {
    final List<FlutterProgramTransformer> transformers =
        FlutterTarget.flutterProgramTransformers;
    if (!transformers.contains(aspectdAopTransformer)) {
      transformers.add(aspectdAopTransformer);
    }
    return _compiler.compile(entryPoint, options, generator: generator);
  }

  @override
  void acceptLastDelta() {
    _compiler.acceptLastDelta();
  }

  @override
  Future<Null> compileExpression(
      String expression,
      List<String> definitions,
      List<String> typeDefinitions,
      String libraryUri,
      String klass,
      bool isStatic) {
    return _compiler.compileExpression(
        expression, definitions, typeDefinitions, libraryUri, klass, isStatic);
  }

  @override
  Future<Null> compileExpressionToJs(
      String libraryUri,
      int line,
      int column,
      Map<String, String> jsModules,
      Map<String, String> jsFrameValues,
      String moduleName,
      String expression) {
    return _compiler.compileExpressionToJs(
        libraryUri, line, column, jsModules, jsFrameValues, moduleName, expression);
  }

  @override
  void invalidate(Uri uri) {
    _compiler.invalidate(uri);
  }

  @override
  Future<Null> recompileDelta({String entryPoint}) {
    return _compiler.recompileDelta(entryPoint: entryPoint);
  }

  @override
  Future<void> rejectLastDelta() {
    return _compiler.rejectLastDelta();
  }

  @override
  void reportError(String msg) {
    return _compiler.reportError(msg);
  }

  @override
  void resetIncrementalCompiler() {
    return _compiler.resetIncrementalCompiler();
  }

}

/// Entry point for this module, that creates `FrontendCompiler` instance and
/// processes user input.
/// `compiler` is an optional parameter so it can be replaced with mocked
/// version for testing.
Future<int> starter(
    List<String> args, {
      frontend.CompilerInterface compiler,
      Stream<List<int>> input,
      StringSink output,
    }) async {
  ArgResults options;
  try {
    options = frontend.argParser.parse(args);
  } catch (error) {
    print('ERROR: $error\n');
    print(frontend.usage);
    return 1;
  }

  if (options['train'] as bool) {
    if (!options.rest.isNotEmpty) {
      throw Exception('Must specify input.dart');
    }

    final String input = options.rest[0];
    final String sdkRoot = options['sdk-root'] as String;
    final Directory temp =
    Directory.systemTemp.createTempSync('train_frontend_server');
    try {
      for (int i = 0; i < 3; i++) {
        final String outputTrainingDill = path.join(temp.path, 'app.dill');
        options = frontend.argParser.parse(<String>[
          '--incremental',
          '--sdk-root=$sdkRoot',
          '--output-dill=$outputTrainingDill',
          '--target=flutter',
          '--track-widget-creation',
          '--enable-asserts',
        ]);
        compiler ??= _FlutterFrontendCompiler(output);

        await compiler.compile(input, options);
        compiler.acceptLastDelta();
        await compiler.recompileDelta();
        compiler.acceptLastDelta();
        compiler.resetIncrementalCompiler();
        await compiler.recompileDelta();
        compiler.acceptLastDelta();
        await compiler.recompileDelta();
        compiler.acceptLastDelta();
      }
      return 0;
    } finally {
      temp.deleteSync(recursive: true);
    }
  }

  compiler ??= _FlutterFrontendCompiler(output,
      useDebuggerModuleNames: options['debugger-module-names'] as bool,
      emitDebugMetadata: options['experimental-emit-debug-metadata'] as bool,
      unsafePackageSerialization:
      options['unsafe-package-serialization'] as bool);

  if (options.rest.isNotEmpty) {
    return await compiler.compile(options.rest[0], options) ? 0 : 254;
  }

  final Completer<int> completer = Completer<int>();
  frontend.listenAndCompile(compiler, input ?? stdin, options, completer);
  return completer.future;
}