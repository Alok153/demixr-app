package com.demixr.demixr_app;

import android.content.ContentResolver;
import android.content.ContentValues;
import android.net.Uri;
import android.os.Build;
import android.os.Environment;
import android.provider.MediaStore;

import androidx.annotation.NonNull;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.util.Map;

import io.flutter.Log;
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends FlutterActivity {
  private static final String EXPORT_CHANNEL = "audio_export";
  private static final String MUSIC_FOLDER = "Music/Demixr";

  @Override
  public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
    super.configureFlutterEngine(flutterEngine);
    try {
      flutterEngine.getPlugins().add(new DemixingPlugin());
    } catch (Exception e) {
      Log.e("MainActivity", "Error registering plugin demixing, DemixingPlugin", e);
    }

    new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), EXPORT_CHANNEL)
        .setMethodCallHandler(this::handleExportChannel);
  }

  private void handleExportChannel(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
    try {
      if ("requiresLegacyStoragePermission".equals(call.method)) {
        result.success(Build.VERSION.SDK_INT < Build.VERSION_CODES.Q);
        return;
      }

      if (!"exportStems".equals(call.method)) {
        result.notImplemented();
        return;
      }

      final String originalFileName = call.argument("originalFileName");
      final Map<String, String> stems = call.argument("stems");

      if (originalFileName == null || originalFileName.trim().isEmpty || stems == null || stems.isEmpty()) {
        result.error("ExportError", "Invalid stem export request.", null);
        return;
      }

      final String sanitizedBaseName = sanitizeFileName(originalFileName);
      exportStemFiles(stems, sanitizedBaseName);
      result.success(MUSIC_FOLDER);
    } catch (Exception e) {
      result.error("ExportError", e.getMessage(), null);
    }
  }

  private void exportStemFiles(Map<String, String> stems, String baseName) throws IOException {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
      exportViaMediaStore(stems, baseName);
      return;
    }

    File musicDir = new File(Environment.getExternalStoragePublicDirectory(
        Environment.DIRECTORY_MUSIC), "Demixr");
    if (!musicDir.exists() && !musicDir.mkdirs()) {
      throw new IOException("Unable to create export folder.");
    }

    for (Map.Entry<String, String> entry : stems.entrySet()) {
      String fileName = baseName + "_" + entry.getKey() + ".wav";
      File outputFile = new File(musicDir, fileName);
      copyFile(new File(entry.getValue()), outputFile);
    }
  }

  private void exportViaMediaStore(Map<String, String> stems, String baseName) throws IOException {
    ContentResolver resolver = getContentResolver();

    for (Map.Entry<String, String> entry : stems.entrySet()) {
      String fileName = baseName + "_" + entry.getKey() + ".wav";
      Uri collection = MediaStore.Audio.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY);

      ContentValues values = new ContentValues();
      values.put(MediaStore.Audio.Media.DISPLAY_NAME, fileName);
      values.put(MediaStore.Audio.Media.MIME_TYPE, "audio/wav");
      values.put(MediaStore.Audio.Media.RELATIVE_PATH, MUSIC_FOLDER);
      values.put(MediaStore.Audio.Media.IS_PENDING, 1);

      Uri uri = resolver.insert(collection, values);
      if (uri == null) {
        throw new IOException("Unable to create media store entry for " + fileName);
      }

      try (OutputStream outputStream = resolver.openOutputStream(uri);
           InputStream inputStream = new FileInputStream(entry.getValue())) {
        if (outputStream == null) {
          throw new IOException("Unable to open output stream for " + fileName);
        }

        copyStream(inputStream, outputStream);
      }

      ContentValues completeValues = new ContentValues();
      completeValues.put(MediaStore.Audio.Media.IS_PENDING, 0);
      resolver.update(uri, completeValues, null, null);
    }
  }

  private void copyFile(File source, File destination) throws IOException {
    try (InputStream inputStream = new FileInputStream(source);
         OutputStream outputStream = new FileOutputStream(destination, false)) {
      copyStream(inputStream, outputStream);
    }
  }

  private void copyStream(InputStream inputStream, OutputStream outputStream) throws IOException {
    byte[] buffer = new byte[8192];
    int bytesRead;
    while ((bytesRead = inputStream.read(buffer)) != -1) {
      outputStream.write(buffer, 0, bytesRead);
    }
    outputStream.flush();
  }

  private String sanitizeFileName(String input) {
    String sanitized = input.replaceAll("[\\\\/:*?\"<>|]", "_").trim();
    if (sanitized.isEmpty()) {
      return "demixr_export";
    }
    return sanitized;
  }
}
